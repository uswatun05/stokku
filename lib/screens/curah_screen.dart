import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../models/item_model.dart';
import '../services/storage_service.dart';
import '../services/audio_service.dart';

class CurahScreen extends StatefulWidget {
  const CurahScreen({super.key});

  @override
  State<CurahScreen> createState() => _CurahScreenState();
}

class _CurahScreenState extends State<CurahScreen> with SingleTickerProviderStateMixin {
  List<ItemModel> _curahItems = [];
  ItemModel? _selectedItem;
  bool _isLoading = true;

  // Controller Kamera & Animasi Laser AI
  late MobileScannerController _cameraController;
  bool _isCameraActive = true;
  late AnimationController _laserAnimController;
  late Animation<double> _laserAnimation;

  // Controller Input Takaran Timbangan
  final TextEditingController _amountController = TextEditingController(text: '1.0');

  @override
  void initState() {
    super.initState();

    _cameraController = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
      torchEnabled: false,
    );

    // Animasi Garis Laser AI Vision (Warna Indigo/Cyan)
    _laserAnimController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);

    _laserAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _laserAnimController, curve: Curves.easeInOut),
    );

    _loadData();
  }

  @override
  void dispose() {
    _cameraController.dispose();
    _laserAnimController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final all = await StorageService().loadInventory();
    final curahList = all.where((i) => i.isCurah).toList();

    setState(() {
      _curahItems = curahList;
      _isLoading = false;

      if (_selectedItem != null) {
        _selectedItem = _curahListOrNull(curahList, _selectedItem!.id);
      } else if (curahList.isNotEmpty) {
        _selectedItem = curahList.first;
      }
    });
  }

  ItemModel? _curahListOrNull(List<ItemModel> list, String id) {
    try {
      return list.firstWhere((i) => i.id == id);
    } catch (_) {
      return list.isNotEmpty ? list.first : null;
    }
  }

  String _formatStock(double val) {
    return val % 1 == 0 ? val.toInt().toString() : val.toStringAsFixed(1);
  }

  // ==========================================
  // LOGIKA DETEKSI PRESET & TRANSAKSI TIMBANGAN
  // ==========================================
  void _selectCommodity(ItemModel item) {
    setState(() {
      _selectedItem = item;
    });

    // Audio feedback: Scan chirp khas deteksi AI
    AudioService().playScan();

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('🎯 AI Terdeteksi: ${item.name} (${item.confidence ?? '96.4%'})'),
        duration: const Duration(seconds: 1),
        backgroundColor: const Color(0xFF6366F1),
      ),
    );
  }

  void _setAmount(double value) {
    setState(() {
      _amountController.text = _formatStock(value);
    });
  }

  void _incrementAmount(double delta) {
    final current = double.tryParse(_amountController.text) ?? 1.0;
    final next = (current + delta).clamp(0.1, 999.0);
    _setAmount(next);
  }

  Future<void> _processTransaction(String direction) async {
    if (_selectedItem == null) {
      AudioService().playWarning();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pilih komoditas curah terlebih dahulu!'),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
      return;
    }

    final amount = double.tryParse(_amountController.text) ?? 0.0;
    if (amount <= 0) {
      AudioService().playWarning();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Masukkan kuantitas timbangan yang valid (> 0)!'),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
      return;
    }

    final item = _selectedItem!;
    final isKeluar = direction == 'keluar';

    // Validasi jika stok keluar melebihi stok yang ada
    if (isKeluar && item.stock < amount) {
      AudioService().playWarning();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('⚠️ Stok ${item.name} tidak cukup (Sisa: ${_formatStock(item.stock)} ${item.unit})'),
          backgroundColor: const Color(0xFFDC2626),
        ),
      );
      return;
    }

    final delta = isKeluar ? -amount : amount;
    final actionName = isKeluar ? 'Penjualan Curah' : 'Timbang Masuk (Beli)';

    final updated = await StorageService().adjustStockDelta(
      item.id,
      delta,
      customAction: actionName,
    );

    if (updated != null) {
      await AudioService().playSuccess();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isKeluar
                ? '✅ Berhasil Dijual: ${item.name} -${_formatStock(amount)} ${item.unit} (Sisa: ${_formatStock(updated.stock)} ${item.unit})'
                : '✅ Berhasil Tambah Stok: ${item.name} +${_formatStock(amount)} ${item.unit} (Total: ${_formatStock(updated.stock)} ${item.unit})',
          ),
          backgroundColor: isKeluar ? const Color(0xFFDC2626) : const Color(0xFF10B981),
        ),
      );

      _loadData();
    }
  }

  // ==========================================
  // WIDGET BUILDER UI
  // ==========================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF020617), // slate-950
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF818CF8)))
          : RefreshIndicator(
              onRefresh: _loadData,
              color: const Color(0xFF818CF8),
              backgroundColor: const Color(0xFF0F172A),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(14.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. HEADER AI VISION SCANNER
                    _buildAiVisionHeader(),

                    const SizedBox(height: 12),

                    // 2. KAMERA AI VISION & BOUNDING BOX OVERLAY
                    _buildAiCameraViewport(),

                    const SizedBox(height: 14),

                    // 3. DAFTAR TOMBOL PRESET BARANG CURAH
                    _buildPresetCommoditySection(),

                    const SizedBox(height: 14),

                    // 4. ACTION CARD: PENCATATAN TIMBANGAN CURAH
                    _buildScaleActionCard(),

                    const SizedBox(height: 16),

                    // 5. BANNER PENJELASAN RISET WIZARD OF OZ
                    _buildAiInfoBanner(),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildAiVisionHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF312E81), Color(0xFF0F172A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.4)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF818CF8).withOpacity(0.4)),
                ),
                child: const Icon(LucideIcons.eye, color: Color(0xFFA5B4FC), size: 20),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Computer Vision Engine',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4F46E5),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'AI VISION',
                          style: TextStyle(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.w900),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Pengenalan Komoditas Curah Tanpa Label',
                    style: TextStyle(color: Color(0xFFC7D2FE), fontSize: 10),
                  ),
                ],
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFF064E3B).withOpacity(0.8),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF10B981).withOpacity(0.5)),
            ),
            child: const Text(
              'Akurasi: 96.4%',
              style: TextStyle(color: Color(0xFF6EE7B7), fontSize: 10, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAiCameraViewport() {
    final item = _selectedItem;

    return Container(
      height: 220,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF020617),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.4), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4F46E5).withOpacity(0.15),
            blurRadius: 16,
            spreadRadius: 2,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Live MobileScanner Camera Feed
            if (_isCameraActive)
              MobileScanner(
                controller: _cameraController,
                onDetect: (_) {},
              )
            else
              Container(
                color: const Color(0xFF0F172A),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(item?.img ?? '🥚', style: const TextStyle(fontSize: 48)),
                      const SizedBox(height: 6),
                      Text(
                        item?.name ?? 'Kamera AI Nonaktif',
                        style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),

            // AI Bounding Box Overlay
            Positioned(
              top: 24,
              bottom: 24,
              left: 28,
              right: 28,
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: const Color(0xFF10B981).withOpacity(0.8),
                    width: 2,
                    style: BorderStyle.solid,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  color: const Color(0xFF10B981).withOpacity(0.04),
                ),
                padding: const EdgeInsets.all(8),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Dynamic AI Label Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F172A).withOpacity(0.9),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFF10B981).withOpacity(0.5)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(item?.img ?? '🔍', style: const TextStyle(fontSize: 12)),
                              const SizedBox(width: 4),
                              Text(
                                item != null ? '${item.name} (${item.confidence ?? '96.4%'})' : 'Menunggu objek...',
                                style: const TextStyle(
                                  color: Color(0xFF6EE7B7),
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.7),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'YOLOv8 Edge',
                            style: TextStyle(color: Color(0xFFA5B4FC), fontSize: 9, fontFamily: 'monospace'),
                          ),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.7),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'FPS: 60 • 1080p',
                            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 8.5),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6366F1).withOpacity(0.3),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Latency: < 45ms',
                            style: TextStyle(color: Color(0xFFC7D2FE), fontSize: 8.5, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Scanning Laser Line (Animasi Turun-Naik Berulang)
            AnimatedBuilder(
              animation: _laserAnimation,
              builder: (context, child) {
                return Positioned(
                  top: _laserAnimation.value * 168 + 26,
                  left: 30,
                  right: 30,
                  child: Container(
                    height: 2.5,
                    decoration: BoxDecoration(
                      color: const Color(0xFF818CF8),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF818CF8).withOpacity(0.9),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),

            // Tombol Toggle Kamera di pojok kanan atas
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                icon: Icon(
                  _isCameraActive ? LucideIcons.video : LucideIcons.videoOff,
                  color: Colors.white70,
                  size: 18,
                ),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black.withOpacity(0.5),
                  padding: const EdgeInsets.all(6),
                ),
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
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPresetCommoditySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Preset Komoditas Curah (Simulasi Touch Trigger):',
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.w600),
            ),
            Text(
              '${_curahItems.length} Item',
              style: const TextStyle(color: Color(0xFF818CF8), fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Grid Kartu Preset Barang Curah
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _curahItems.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 1.15,
          ),
          itemBuilder: (context, index) {
            final item = _curahItems[index];
            final isSelected = _selectedItem?.id == item.id;

            return InkWell(
              onTap: () => _selectCommodity(item),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF312E81) : const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected ? const Color(0xFF818CF8) : const Color(0xFF1E293B),
                    width: isSelected ? 1.8 : 1.0,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(item.img, style: const TextStyle(fontSize: 22)),
                    const SizedBox(height: 4),
                    Text(
                      item.name,
                      style: TextStyle(
                        color: isSelected ? Colors.white : const Color(0xFFE2E8F0),
                        fontSize: 10.5,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_formatStock(item.stock)} ${item.unit}',
                      style: TextStyle(
                        color: isSelected ? const Color(0xFF6EE7B7) : const Color(0xFF64748B),
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildScaleActionCard() {
    final item = _selectedItem;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A), // slate-900
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row Header: Item Terpilih & Sisa Stok
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('KOMODITAS AKTIF:', style: TextStyle(color: Color(0xFF818CF8), fontSize: 9.5, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text(
                    item?.name ?? 'Pilih komoditas di atas',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('Sisa Stok Saat Ini', style: TextStyle(color: Color(0xFF64748B), fontSize: 9.5)),
                  const SizedBox(height: 2),
                  Text(
                    item != null ? '${_formatStock(item.stock)} ${item.unit}' : '-',
                    style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.w900, fontSize: 14),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Input Kuantitas Takaran & Quick Buttons
          const Text('Jumlah Takaran / Timbangan:', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
          const SizedBox(height: 6),
          Row(
            children: [
              // TextField Takaran
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF334155)),
                  ),
                  child: TextField(
                    controller: _amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Badge Satuan
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                child: Text(
                  item?.unit ?? 'kg',
                  style: const TextStyle(color: Color(0xFFA5B4FC), fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Quick Increment Buttons (+0.25, +0.5, +1.0, +2.0)
          Row(
            children: [
              const Text('Cepat:', style: TextStyle(color: Color(0xFF64748B), fontSize: 10)),
              const SizedBox(width: 8),
              _buildQuickAmountBtn('0.25', 0.25),
              const SizedBox(width: 6),
              _buildQuickAmountBtn('0.5', 0.5),
              const SizedBox(width: 6),
              _buildQuickAmountBtn('1.0', 1.0),
              const SizedBox(width: 6),
              _buildQuickAmountBtn('2.0', 2.0),
            ],
          ),

          const SizedBox(height: 16),

          // Action Buttons: Jual (Merah) vs Tambah Stok (Hijau)
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _processTransaction('keluar'),
                  icon: const Icon(LucideIcons.minusCircle, size: 16),
                  label: const Text('Jual / Kurang', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFDC2626),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 3,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _processTransaction('masuk'),
                  icon: const Icon(LucideIcons.plusCircle, size: 16),
                  label: const Text('Beli / Tambah', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 3,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAmountBtn(String label, double val) {
    return InkWell(
      onTap: () => _setAmount(val),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF334155)),
        ),
        child: Text(
          label,
          style: const TextStyle(color: Color(0xFFE2E8F0), fontSize: 10.5, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildAiInfoBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF6366F1).withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(LucideIcons.sparkles, color: Color(0xFF818CF8), size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pendekatan Wizard of Oz & Touch Trigger',
                  style: TextStyle(color: Color(0xFFA5B4FC), fontWeight: FontWeight.bold, fontSize: 12),
                ),
                SizedBox(height: 2),
                Text(
                  'Memungkinkan kasir warung mencatat transaksi komoditas tanpa barcode (telur, beras, bawang) secara presisi dengan takaran desimal.',
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
