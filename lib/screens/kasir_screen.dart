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
  // Controller Kamera Pemindai Barcode
  late MobileScannerController _cameraController;
  bool _isCameraOpen = true; // Toggle Buka/Tutup Kamera Scanner
  bool _isTorchOn = false;

  // Animasi Garis Laser Bidik Barcode (Merah Standar POS Ritel)
  late AnimationController _laserAnimController;
  late Animation<double> _laserAnimation;

  // Input Barcode Manual & Barcode Scanner Gun Controller
  final TextEditingController _barcodeInputController = TextEditingController();
  final FocusNode _barcodeFocusNode = FocusNode();

  // State Keranjang Transaksi & Feedback Scan Terakhir
  final List<CartItemModel> _cartItems = [];
  List<ItemModel> _catalogItems = [];
  ItemModel? _lastScannedItem;
  String _scanStatusText = 'Siap Scan Barcode';
  String _scanStatusMeta = 'Arahkan kamera ke barcode kemasan/curah atau ketik kode di bawah.';
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

    // 1. Inisialisasi Mobile Scanner khusus Barcode Standar
    _cameraController = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
      torchEnabled: false,
    );

    // 2. Animasi Garis Laser Pemindai (Turun-Naik)
    _laserAnimController = AnimationController(
      duration: const Duration(milliseconds: 1800),
      vsync: this,
    )..repeat(reverse: true);

    _laserAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _laserAnimController, curve: Curves.easeInOut),
    );

    _loadCatalog();
  }

  @override
  void dispose() {
    _cameraController.dispose();
    _laserAnimController.dispose();
    _barcodeInputController.dispose();
    _barcodeFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadCatalog() async {
    final items = await StorageService().loadInventory();
    if (mounted) {
      setState(() {
        _catalogItems = items;
      });
    }
  }

  // ==========================================
  // LOGIKA PEMINDAIAN KAMERA & BARCODE
  // ==========================================

  void _onBarcodeDetected(BarcodeCapture capture) {
    if (!_isCameraOpen) return;

    final now = DateTime.now();
    // Debounce: Hindari pemindaian beruntun dalam 1.2 detik untuk barcode yang sama
    if (_lastScanTimestamp != null &&
        now.difference(_lastScanTimestamp!).inMilliseconds < 1200) {
      return;
    }

    final barcodes = capture.barcodes;
    if (barcodes.isNotEmpty && barcodes.first.rawValue != null) {
      final code = barcodes.first.rawValue!.trim();
      if (code.isNotEmpty) {
        _lastScanTimestamp = now;
        _processBarcode(code);
      }
    }
  }

  void _processBarcode(String rawBarcode) {
    final barcode = rawBarcode.trim();
    if (barcode.isEmpty) return;

    final item = StorageService().getItemByBarcode(barcode);

    if (item != null) {
      _addItemToCart(item);
    } else {
      AudioService().playWarning();

      setState(() {
        _lastScannedItem = null;
        _isLastScanSuccess = false;
        _scanStatusText = 'Barcode Tidak Ditemukan!';
        _scanStatusMeta = 'Kode: "$barcode" belum terdaftar di sistem stok.';
      });

      _showCustomSnackBar(
        title: 'Barcode Belum Terdaftar',
        message: 'Kode "$barcode" tidak ada di inventaris warung.',
        isError: true,
      );
    }

    _barcodeInputController.clear();
    _barcodeFocusNode.requestFocus();
  }

  void _addItemToCart(ItemModel item) {
    AudioService().playSuccess();

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
  }

  void _toggleCamera() {
    setState(() {
      _isCameraOpen = !_isCameraOpen;
      if (_isCameraOpen) {
        _cameraController.start();
      } else {
        _cameraController.stop();
      }
    });
  }

  Future<void> _toggleTorch() async {
    if (!_isCameraOpen) return;
    await _cameraController.toggleTorch();
    setState(() {
      _isTorchOn = !_isTorchOn;
    });
  }

  Future<void> _switchCamera() async {
    if (!_isCameraOpen) return;
    await _cameraController.switchCamera();
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

  void _clearCart() {
    if (_cartItems.isEmpty) return;
    setState(() {
      _cartItems.clear();
      _lastScannedItem = null;
      _scanStatusText = 'Keranjang Dikosongkan';
      _scanStatusMeta = 'Silakan scan barcode barang berikutnya.';
    });
    AudioService().playWarning();
  }

  double get _totalCartPrice {
    return _cartItems.fold(0.0, (sum, item) => sum + item.subtotal);
  }

  double get _totalCartItemsCount {
    return _cartItems.fold(0.0, (sum, item) => sum + item.qty);
  }

  // ==========================================
  // CHECKOUT & POTONG STOK
  // ==========================================

  Future<void> _handleCheckout() async {
    if (_cartItems.isEmpty) {
      AudioService().playWarning();
      _showCustomSnackBar(
        title: 'Keranjang Masih Kosong',
        message: 'Scan atau pilih barang terlebih dahulu untuk transaksi kasir.',
        isError: true,
      );
      return;
    }

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
                color: const Color(0xFF10B981).withValues(alpha: 0.2),
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
              'Transaksi kasir berhasil dicatat dan stok inventaris terpotong secara instan.',
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
                        style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.w900, fontSize: 16),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Transaksi Baru', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckoutConfirmationSheet(BuildContext ctx) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
        left: 20,
        right: 20,
        top: 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFF334155),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Konfirmasi Checkout Kasir',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${_cartItems.length} SKU',
                  style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 11),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Pastikan pembayaran pembeli telah diterima sebelum memotong stok inventaris.',
            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
          ),
          const SizedBox(height: 16),
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
                        '${item.qty} ${item.item.unit} • ${currencyFormatter.format(item.subtotal)}',
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
            // 1. TERMINAL SCANNER BARCODE (KAMERA + MANUAL)
            _buildScannerInputCard(),

            const SizedBox(height: 12),

            // 2. KARTU FEEDBACK SCAN TERAKHIR
            _buildLastScanFeedbackCard(),

            const SizedBox(height: 12),

            // 3. SHORTCUT KATALOG CEPAT
            _buildQuickCatalogSection(),

            const SizedBox(height: 12),

            // 4. DAFTAR KERANJANG TRANSAKSI KASIR
            _buildCartSection(),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildScannerInputCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A), // slate-900
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF10B981).withValues(alpha: 0.3),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row: Status & Tombol "Buka/Tutup Kamera Scanner"
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(LucideIcons.scanLine, color: Color(0xFF10B981), size: 20),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Terminal Kasir Barcode',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      Text(
                        _isCameraOpen ? 'Scanner Kamera Aktif' : 'Mode Manual (Kamera Tutup)',
                        style: TextStyle(
                          color: _isCameraOpen ? const Color(0xFF6EE7B7) : const Color(0xFF94A3B8),
                          fontSize: 10.5,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              // Tombol "Buka/Tutup Kamera Scanner"
              ElevatedButton.icon(
                onPressed: _toggleCamera,
                icon: Icon(
                  _isCameraOpen ? LucideIcons.cameraOff : LucideIcons.camera,
                  size: 13,
                ),
                label: Text(
                  _isCameraOpen ? 'Tutup Kamera' : 'Buka Kamera',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isCameraOpen ? const Color(0xFF1E293B) : const Color(0xFF10B981),
                  foregroundColor: _isCameraOpen ? Colors.white70 : Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  side: _isCameraOpen ? const BorderSide(color: Color(0xFF334155)) : BorderSide.none,
                ),
              ),
            ],
          ),

          // Area Kamera Scanner Barcode (Tampil jika _isCameraOpen = true)
          if (_isCameraOpen) ...[
            Container(
              margin: const EdgeInsets.only(top: 14),
              height: 190,
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFF020617),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4), width: 1.5),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Feed Kamera MobileScanner
                    MobileScanner(
                      controller: _cameraController,
                      onDetect: _onBarcodeDetected,
                    ),

                    // Kotak Target Barcode & Garis Laser Pemindai Merah
                    Center(
                      child: Container(
                        width: 240,
                        height: 110,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: const Color(0xFF10B981).withValues(alpha: 0.8),
                            width: 2.0,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          color: Colors.black.withValues(alpha: 0.15),
                        ),
                        child: Stack(
                          children: [
                            // Garis Laser Animasi
                            AnimatedBuilder(
                              animation: _laserAnimation,
                              builder: (context, child) {
                                return Positioned(
                                  top: _laserAnimation.value * 94 + 6,
                                  left: 10,
                                  right: 10,
                                  child: Container(
                                    height: 2.5,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEF4444), // Laser merah ritel
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFFEF4444).withValues(alpha: 0.9),
                                          blurRadius: 8,
                                          spreadRadius: 1.5,
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                            Positioned(
                              bottom: 6,
                              left: 0,
                              right: 0,
                              child: Center(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.75),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    'Arahkan garis merah ke garis barcode',
                                    style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Kontrol Cepat: Senter Flash & Switch Kamera
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Row(
                        children: [
                          IconButton(
                            icon: Icon(
                              _isTorchOn ? LucideIcons.zap : LucideIcons.zapOff,
                              size: 15,
                              color: _isTorchOn ? const Color(0xFFFBBF24) : Colors.white70,
                            ),
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.black.withValues(alpha: 0.6),
                              padding: const EdgeInsets.all(6),
                            ),
                            onPressed: _toggleTorch,
                          ),
                          const SizedBox(width: 4),
                          IconButton(
                            icon: const Icon(LucideIcons.switchCamera, size: 15, color: Colors.white70),
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.black.withValues(alpha: 0.6),
                              padding: const EdgeInsets.all(6),
                            ),
                            onPressed: _switchCamera,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
            // Banner Mode Kamera Tertutup (Hemat Layar)
            Container(
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: const Row(
                children: [
                  Icon(LucideIcons.keyboard, color: Color(0xFF94A3B8), size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Kamera dinonaktifkan. Ketik barcode atau gunakan barcode scanner gun.',
                      style: TextStyle(color: Color(0xFF94A3B8), fontSize: 10.5),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 12),

          // Input Barcode Field (Ketik Manual / Scanner Gun)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.5), width: 1.5),
            ),
            child: Row(
              children: [
                const Icon(LucideIcons.scanLine, color: Color(0xFF10B981), size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _barcodeInputController,
                    focusNode: _barcodeFocusNode,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                    textInputAction: TextInputAction.go,
                    onSubmitted: _processBarcode,
                    decoration: const InputDecoration(
                      hintText: 'Scan / Ketik kode barcode (misal: CRH-8066)...',
                      hintStyle: TextStyle(color: Color(0xFF64748B), fontSize: 11.5, fontWeight: FontWeight.normal),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(LucideIcons.cornerDownLeft, size: 18, color: Color(0xFF10B981)),
                  tooltip: 'Submit Barcode',
                  onPressed: () => _processBarcode(_barcodeInputController.text),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLastScanFeedbackCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isLastScanSuccess
              ? const Color(0xFF10B981).withValues(alpha: 0.3)
              : const Color(0xFFEF4444).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _isLastScanSuccess
                  ? const Color(0xFF10B981).withValues(alpha: 0.15)
                  : const Color(0xFFEF4444).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                _lastScannedItem?.img ?? (_isLastScanSuccess ? '🏷️' : '⚠️'),
                style: const TextStyle(fontSize: 20),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _scanStatusText,
                  style: TextStyle(
                    color: _isLastScanSuccess ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
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
            Text(
              currencyFormatter.format(_lastScannedItem!.price),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
            ),
        ],
      ),
    );
  }

  Widget _buildQuickCatalogSection() {
    if (_catalogItems.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Pilih Cepat Produk (Tanpa Scan Barcode):',
          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 38,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _catalogItems.length,
            separatorBuilder: (_, __) => const SizedBox(width: 6),
            itemBuilder: (context, index) {
              final item = _catalogItems[index];
              return InkWell(
                onTap: () => _addItemToCart(item),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF1E293B)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(item.img, style: const TextStyle(fontSize: 14)),
                      const SizedBox(width: 6),
                      Text(
                        item.name,
                        style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        currencyFormatter.format(item.price),
                        style: const TextStyle(color: Color(0xFF10B981), fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCartSection() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF1E293B)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Keranjang
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(LucideIcons.shoppingBag, color: Color(0xFF10B981), size: 18),
                    const SizedBox(width: 8),
                    const Text(
                      'Keranjang Transaksi',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${_cartItems.length} Item',
                        style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 10.5),
                      ),
                    ),
                  ],
                ),
                if (_cartItems.isNotEmpty)
                  TextButton.icon(
                    onPressed: _clearCart,
                    icon: const Icon(LucideIcons.trash2, size: 14, color: Color(0xFFEF4444)),
                    label: const Text('Kosongkan', style: TextStyle(color: Color(0xFFEF4444), fontSize: 11)),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
              ],
            ),
          ),

          const Divider(color: Color(0xFF1E293B), height: 1),

          // Daftar Item Keranjang
          if (_cartItems.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 36),
              child: Center(
                child: Column(
                  children: [
                    Icon(LucideIcons.shoppingCart, color: Color(0xFF334155), size: 40),
                    SizedBox(height: 8),
                    Text(
                      'Keranjang Masih Kosong',
                      style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Scan barcode produk atau pilih produk di atas untuk memulai transaksi.',
                      style: TextStyle(color: Color(0xFF64748B), fontSize: 11),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _cartItems.length,
              separatorBuilder: (_, __) => const Divider(color: Color(0xFF1E293B), height: 1),
              itemBuilder: (context, index) {
                final cartItem = _cartItems[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(cartItem.item.img, style: const TextStyle(fontSize: 18)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              cartItem.item.name,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12.5),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${currencyFormatter.format(cartItem.item.price)} / ${cartItem.item.unit}',
                              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 10.5),
                            ),
                          ],
                        ),
                      ),
                      // Stepper Qty (- / +)
                      Row(
                        children: [
                          _buildStepperBtn(LucideIcons.minus, () => _updateCartItemQty(index, -1.0)),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Text(
                              cartItem.qty % 1 == 0 ? cartItem.qty.toInt().toString() : cartItem.qty.toStringAsFixed(1),
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ),
                          _buildStepperBtn(LucideIcons.plus, () => _updateCartItemQty(index, 1.0)),
                        ],
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            currencyFormatter.format(cartItem.subtotal),
                            style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 12.5),
                          ),
                          InkWell(
                            onTap: () => _removeCartItem(index),
                            child: const Text('Hapus', style: TextStyle(color: Color(0xFFEF4444), fontSize: 9.5)),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),

          if (_cartItems.isNotEmpty) ...[
            const Divider(color: Color(0xFF1E293B), height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('TOTAL BAYAR:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                      Text(
                        currencyFormatter.format(_totalCartPrice),
                        style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.w900, fontSize: 20),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _handleCheckout,
                      icon: const Icon(LucideIcons.creditCard, size: 18),
                      label: const Text('Bayar / Selesaikan Transaksi', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStepperBtn(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFF334155)),
        ),
        child: Icon(icon, size: 12, color: Colors.white70),
      ),
    );
  }
}
