import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../models/item_model.dart';
import '../models/cart_item_model.dart';
import '../services/storage_service.dart';
import '../services/audio_service.dart';

class KasirScreen extends StatefulWidget {
  const KasirScreen({super.key});

  @override
  State<KasirScreen> createState() => _KasirScreenState();
}

class _KasirScreenState extends State<KasirScreen> with SingleTickerProviderStateMixin {
  // Controller Kamera Mobile Scanner
  late MobileScannerController _cameraController;
  bool _isCameraActive = true;
  bool _isTorchOn = false;

  // Animasi Garis Laser Bidik
  late AnimationController _laserAnimController;
  late Animation<double> _laserAnimation;

  // Input Barcode Manual
  final TextEditingController _manualBarcodeController = TextEditingController();

  // State Keranjang Transaksi & Feedback Scan Terakhir
  final List<CartItemModel> _cartItems = [];
  ItemModel? _lastScannedItem;
  String _scanStatusText = 'Siap Memindai Produk';
  String _scanStatusMeta = 'Arahkan kamera ke barcode kemasan atau ketik manual.';
  bool _isLastScanSuccess = true;
  DateTime? _lastScanTimestamp;

  final currencyFormatter = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();

    // Inisialisasi Mobile Scanner Controller
    _cameraController = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
      torchEnabled: false,
    );

    // Inisialisasi Animasi Laser Pemindai (Atas-Bawah bolak-balik)
    _laserAnimController = AnimationController(
      duration: const Duration(milliseconds: 1800),
      vsync: this,
    )..repeat(reverse: true);

    _laserAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _laserAnimController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _cameraController.dispose();
    _laserAnimController.dispose();
    _manualBarcodeController.dispose();
    super.dispose();
  }

  // ==========================================
  // LOGIKA PEMINDAIAN BARCODE & KERANJANG
  // ==========================================

  void _onBarcodeDetected(BarcodeCapture capture) {
    if (!_isCameraActive) return;

    final now = DateTime.now();
    // Debounce: Hindari pemindaian beruntun dalam 1.2 detik untuk barcode yang sama
    if (_lastScanTimestamp != null &&
        now.difference(_lastScanTimestamp!).inMilliseconds < 1200) {
      return;
    }

    final barcodes = capture.barcodes;
    if (barcodes.isNotEmpty && barcodes.first.rawValue != null) {
      final code = barcodes.first.rawValue!.trim();
      _lastScanTimestamp = now;
      _processBarcode(code);
    }
  }

  void _processBarcode(String barcode) {
    if (barcode.isEmpty) return;

    final item = StorageService().getItemByBarcode(barcode);

    if (item != null) {
      // Audio feedback: SUKSES
      AudioService().playSuccess();

      // Tambahkan barang ke keranjang
      setState(() {
        _lastScannedItem = item;
        _isLastScanSuccess = true;
        _scanStatusText = '${item.name} Ditambahkan';
        _scanStatusMeta = 'Barcode: ${item.barcode} • Kategori: ${item.category}';

        final existingIndex = _cartItems.indexWhere((c) => c.item.id == item.id);
        if (existingIndex != -1) {
          _cartItems[existingIndex].qty += 1.0;
        } else {
          _cartItems.add(CartItemModel(item: item, qty: 1.0));
        }
      });
    } else {
      // Audio feedback: WARNING / ERROR
      AudioService().playWarning();

      setState(() {
        _lastScannedItem = null;
        _isLastScanSuccess = false;
        _scanStatusText = 'Barcode Tidak Ditemukan!';
        _scanStatusMeta = 'Kode: "$barcode" belum terdaftar di sistem stok.';
      });

      _showCustomSnackBar(
        title: 'Barcode Tidak Terdaftar',
        message: 'Kode "$barcode" belum ada di database stok inventaris.',
        isError: true,
      );
    }
  }

  void _processManualInput() {
    final code = _manualBarcodeController.text.trim();
    if (code.isEmpty) return;

    _processBarcode(code);
    _manualBarcodeController.clear();
    FocusScope.of(context).unfocus();
  }

  void _updateCartItemQty(int index, double delta) {
    setState(() {
      final current = _cartItems[index];
      final newQty = current.qty + delta;
      if (newQty <= 0) {
        _cartItems.removeAt(index);
      } else {
        current.qty = newQty;
      }
    });
  }

  void _removeCartItem(int index) {
    setState(() {
      _cartItems.removeAt(index);
    });
  }

  double get _totalCartPrice {
    double total = 0.0;
    for (final c in _cartItems) {
      total += c.subtotal;
    }
    return total;
  }

  double get _totalCartItemsCount {
    double count = 0.0;
    for (final c in _cartItems) {
      count += c.qty;
    }
    return count;
  }

  // ==========================================
  // PROSES TRANSAKSI KASIR (POTONG STOK)
  // ==========================================
  Future<void> _completeTransaction() async {
    if (_cartItems.isEmpty) {
      AudioService().playWarning();
      _showCustomSnackBar(
        title: 'Keranjang Kosong',
        message: 'Scan atau ketik barcode produk terlebih dahulu!',
        isError: true,
      );
      return;
    }

    // Tampilkan dialog konfirmasi ringkasan pembayaran
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: const Color(0xFF0F172A),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => _buildCheckoutConfirmationSheet(ctx),
    );

    if (confirmed == true) {
      // Potong stok inventaris melalui StorageService
      for (final cartItem in _cartItems) {
        await StorageService().adjustStockDelta(
          cartItem.item.id,
          -cartItem.qty,
          customAction: 'Kasir Checkout',
        );
      }

      // Audio feedback transaksi selesai
      await AudioService().playSuccess();

      final totalBayar = _totalCartPrice;
      final totalItem = _totalCartItemsCount;

      setState(() {
        _cartItems.clear();
        _lastScannedItem = null;
        _scanStatusText = 'Transaksi Berhasil!';
        _scanStatusMeta = 'Stok otomatis terpotong di database lokal warung.';
        _isLastScanSuccess = true;
      });

      if (!mounted) return;
      _showTransactionSuccessDialog(totalBayar, totalItem);
    }
  }

  void _showTransactionSuccessDialog(double total, double itemsCount) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: Color(0xFF10B981), width: 1.5),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(LucideIcons.checkCircle2, color: Color(0xFF10B981), size: 28),
            ),
            const SizedBox(width: 12),
            const Text(
              'Pembayaran Lunas',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Transaksi berhasil dicatat dan stok inventaris telah diperbarui secara instan.',
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total Kuantitas:', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                      Text('$itemsCount item', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                    ],
                  ),
                  const Divider(color: Color(0xFF334155), height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total Pembayaran:', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                      Text(
                        currencyFormatter.format(total),
                        style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.w900, fontSize: 15),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            child: const Text('Tutup', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckoutConfirmationSheet(BuildContext ctx) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 48,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFF334155),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: const [
              Icon(LucideIcons.shoppingBag, color: Color(0xFF10B981), size: 22),
              SizedBox(width: 8),
              Text(
                'Konfirmasi Selesai Transaksi',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Pastikan uang pembeli telah diterima sebelum memotong stok inventaris.',
            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
          ),
          const SizedBox(height: 16),
          // List ringkasan item
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 180),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: _cartItems.length,
              separatorBuilder: (_, __) => const Divider(color: Color(0xFF1E293B), height: 1),
              itemBuilder: (c, i) {
                final item = _cartItems[i];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          '${item.item.img} ${item.item.name}',
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '${item.qty} ${item.item.unit}  •  ${currencyFormatter.format(item.subtotal)}',
                        style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const Divider(color: Color(0xFF334155), height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('TOTAL TAGIHAN:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
              Text(
                currencyFormatter.format(_totalCartPrice),
                style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.w900, fontSize: 18),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF334155)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Batal', style: TextStyle(color: Colors.white70)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pop(ctx, true),
                  icon: const Icon(LucideIcons.check, size: 18),
                  label: const Text('Proses Bayar', style: TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showCustomSnackBar({required String title, required String message, bool isError = false}) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: isError ? const Color(0xFFDC2626) : const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13)),
            Text(message, style: const TextStyle(color: Colors.white70, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // WIDGET BUILDER UI
  // ==========================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF020617), // slate-950
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. SCANNER CARD CONTAINER (Mirip Card Web)
            _buildScannerCard(),

            const SizedBox(height: 12),

            // 2. KARTU FEEDBACK SCAN TERAKHIR
            _buildLastScanFeedbackCard(),

            const SizedBox(height: 12),

            // 3. INPUT BARCODE MANUAL
            _buildManualBarcodeInput(),

            const SizedBox(height: 12),

            // 4. KERANJANG TRANSAKSI KASIR
            _buildCartSection(),

            const SizedBox(height: 16),

            // 5. BANNER KECEPATAN TRANSAKSI
            _buildQuickHelpBanner(),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildScannerCard() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A), // slate-900
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFF10B981).withOpacity(0.3),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header Status Kamera & Tombol Toggle
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: _isCameraActive ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: (_isCameraActive ? const Color(0xFF10B981) : const Color(0xFFEF4444)).withOpacity(0.6),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _isCameraActive ? 'Kamera Barcode Aktif' : 'Kamera Nonaktif',
                      style: const TextStyle(
                        color: Color(0xFFE2E8F0),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    // Tombol Flash / Torch
                    IconButton(
                      icon: Icon(
                        _isTorchOn ? LucideIcons.zap : LucideIcons.zapOff,
                        size: 16,
                        color: _isTorchOn ? const Color(0xFFFBBF24) : Colors.white60,
                      ),
                      onPressed: () async {
                        await _cameraController.toggleTorch();
                        setState(() {
                          _isTorchOn = !_isTorchOn;
                        });
                      },
                      style: IconButton.styleFrom(
                        backgroundColor: const Color(0xFF1E293B),
                        padding: const EdgeInsets.all(6),
                      ),
                    ),
                    const SizedBox(width: 6),
                    // Tombol Flip Camera
                    IconButton(
                      icon: const Icon(LucideIcons.switchCamera, size: 16, color: Colors.white60),
                      onPressed: () => _cameraController.switchCamera(),
                      style: IconButton.styleFrom(
                        backgroundColor: const Color(0xFF1E293B),
                        padding: const EdgeInsets.all(6),
                      ),
                    ),
                    const SizedBox(width: 6),
                    // Tombol Nyalakan / Matikan Kamera
                    ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          _isCameraActive = !_isCameraActive;
                          if (_isCameraActive) {
                            _cameraController.start();
                          } else {
                            _cameraController.stop();
                          }
                        });
                      },
                      icon: Icon(
                        _isCameraActive ? LucideIcons.cameraOff : LucideIcons.camera,
                        size: 14,
                      ),
                      label: Text(
                        _isCameraActive ? 'Matikan' : 'Aktifkan',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isCameraActive ? const Color(0xFF1E293B) : const Color(0xFF10B981),
                        foregroundColor: _isCameraActive ? Colors.white70 : Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Area Kamera & Laser Reticle
          ClipRRect(
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
            child: SizedBox(
              height: 220,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (_isCameraActive)
                    MobileScanner(
                      controller: _cameraController,
                      onDetect: _onBarcodeDetected,
                    )
                  else
                    Container(
                      color: const Color(0xFF020617),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(LucideIcons.scanLine, color: Color(0xFF10B981), size: 36),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Pemindai Kamera Sedang Istirahat',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Tekan "Aktifkan" di atas atau ketik barcode manual di bawah.',
                              style: TextStyle(color: Color(0xFF64748B), fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Overlay Kotak Bidik Laser
                  if (_isCameraActive)
                    Center(
                      child: SizedBox(
                        width: 250,
                        height: 140,
                        child: Stack(
                          children: [
                            // Frame border
                            Container(
                              decoration: BoxDecoration(
                                border: Border.all(color: const Color(0xFF10B981).withOpacity(0.8), width: 1.5),
                                borderRadius: BorderRadius.circular(14),
                                color: const Color(0xFF10B981).withOpacity(0.05),
                              ),
                            ),
                            // 4 Corner Markers
                            Positioned(top: 2, left: 2, child: _buildCorner(top: true, left: true)),
                            Positioned(top: 2, right: 2, child: _buildCorner(top: true, left: false)),
                            Positioned(bottom: 2, left: 2, child: _buildCorner(top: false, left: true)),
                            Positioned(bottom: 2, right: 2, child: _buildCorner(top: false, left: false)),
                            // Animasi Garis Laser Hijau
                            AnimatedBuilder(
                              animation: _laserAnimation,
                              builder: (context, child) {
                                return Positioned(
                                  top: _laserAnimation.value * 126 + 6,
                                  left: 6,
                                  right: 6,
                                  child: Container(
                                    height: 2.5,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF10B981),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFF10B981).withOpacity(0.9),
                                          blurRadius: 10,
                                          spreadRadius: 1.5,
                                        ),
                                      ],
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),

                  if (_isCameraActive)
                    Positioned(
                      bottom: 10,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.7),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'Arahkan barcode UPC / EAN ke dalam kotak',
                            style: TextStyle(color: Color(0xFF6EE7B7), fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCorner({required bool top, required bool left}) {
    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        border: Border(
          top: top ? const BorderSide(color: Color(0xFF10B981), width: 3) : BorderSide.none,
          bottom: !top ? const BorderSide(color: Color(0xFF10B981), width: 3) : BorderSide.none,
          left: left ? const BorderSide(color: Color(0xFF10B981), width: 3) : BorderSide.none,
          right: !left ? const BorderSide(color: Color(0xFF10B981), width: 3) : BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildLastScanFeedbackCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _isLastScanSuccess ? const Color(0xFF10B981).withOpacity(0.4) : const Color(0xFFDC2626).withOpacity(0.4),
          width: 1.2,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _isLastScanSuccess ? const Color(0xFF10B981).withOpacity(0.15) : const Color(0xFFDC2626).withOpacity(0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              _isLastScanSuccess ? LucideIcons.checkCircle2 : LucideIcons.alertTriangle,
              color: _isLastScanSuccess ? const Color(0xFF10B981) : const Color(0xFFEF4444),
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _isLastScanSuccess ? const Color(0xFF10B981).withOpacity(0.2) : const Color(0xFFDC2626).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _isLastScanSuccess ? 'PEMINDAIAN BERHASIL' : 'PERINGATAN PEMINDAIAN',
                    style: TextStyle(
                      color: _isLastScanSuccess ? const Color(0xFF6EE7B7) : const Color(0xFFFCA5A5),
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _scanStatusText,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  _scanStatusMeta,
                  style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (_lastScannedItem != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text('Sisa Stok', style: TextStyle(color: Color(0xFF64748B), fontSize: 9)),
                Text(
                  '${_lastScannedItem!.stock} ${_lastScannedItem!.unit}',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildManualBarcodeInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1E293B)),
      ),
      child: Row(
        children: [
          const Icon(LucideIcons.keyboard, color: Color(0xFF10B981), size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _manualBarcodeController,
              onSubmitted: (_) => _processManualInput(),
              style: const TextStyle(color: Colors.white, fontSize: 12),
              decoration: const InputDecoration(
                hintText: 'Ketik barcode manual (jika kamera gagal)...',
                hintStyle: TextStyle(color: Color(0xFF64748B), fontSize: 11),
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: _processManualInput,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            ),
            child: const Text('Enter', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildCartSection() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF1E293B)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(LucideIcons.shoppingCart, color: Color(0xFF10B981), size: 18),
                  const SizedBox(width: 8),
                  const Text(
                    'Keranjang Transaksi',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${_cartItems.length} Produk',
                  style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 11),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // List item di keranjang
          if (_cartItems.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 24),
              alignment: Alignment.center,
              child: Column(
                children: const [
                  Icon(LucideIcons.scanLine, color: Color(0xFF334155), size: 36),
                  SizedBox(height: 6),
                  Text(
                    'Belum ada barang di-scan',
                    style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
                  ),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _cartItems.length,
              separatorBuilder: (_, __) => const Divider(color: Color(0xFF1E293B), height: 16),
              itemBuilder: (context, index) {
                final cartItem = _cartItems[index];
                return Row(
                  children: [
                    Text(cartItem.item.img, style: const TextStyle(fontSize: 22)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            cartItem.item.name,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            currencyFormatter.format(cartItem.item.price),
                            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    // Quantity Stepper (- / +)
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(LucideIcons.minus, size: 12, color: Colors.white70),
                            onPressed: () => _updateCartItemQty(index, -1),
                            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                            padding: EdgeInsets.zero,
                          ),
                          Text(
                            '${cartItem.qty.toInt()}',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                          IconButton(
                            icon: const Icon(LucideIcons.plus, size: 12, color: Color(0xFF10B981)),
                            onPressed: () => _updateCartItemQty(index, 1),
                            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                            padding: EdgeInsets.zero,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Tombol Hapus Item
                    IconButton(
                      icon: const Icon(LucideIcons.trash2, size: 16, color: Color(0xFFEF4444)),
                      onPressed: () => _removeCartItem(index),
                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                      padding: EdgeInsets.zero,
                    ),
                  ],
                );
              },
            ),

          const Divider(color: Color(0xFF1E293B), height: 24),

          // Total & Tombol Proses Transaksi
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Total Pembayaran', style: TextStyle(color: Color(0xFF64748B), fontSize: 10)),
                  Text(
                    currencyFormatter.format(_totalCartPrice),
                    style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.w900, fontSize: 17),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: _cartItems.isEmpty ? null : _completeTransaction,
                icon: const Icon(LucideIcons.checkCheck, size: 16),
                label: const Text('Selesaikan Transaksi', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.black,
                  disabledBackgroundColor: const Color(0xFF1E293B),
                  disabledForegroundColor: const Color(0xFF475569),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 4,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickHelpBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF10B981).withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF10B981).withOpacity(0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(LucideIcons.sparkles, color: Color(0xFF10B981), size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Kecepatan Transaksi: < 0.3 Detik',
                  style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 12),
                ),
                SizedBox(height: 2),
                Text(
                  'Stok langsung terpotong secara instan di database lokal offline tanpa lag. Jika menjual barang curah (telur/beras), gunakan tab Curah (AI).',
                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 10.5, height: 1.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
