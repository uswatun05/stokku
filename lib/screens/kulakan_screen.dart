import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../models/item_model.dart';
import '../services/storage_service.dart';
import '../services/audio_service.dart';

class KulakanScreen extends StatefulWidget {
  const KulakanScreen({super.key});

  @override
  State<KulakanScreen> createState() => _KulakanScreenState();
}

class _KulakanScreenState extends State<KulakanScreen> {
  List<ItemModel> _allItems = [];
  ItemModel? _selectedItem;
  final TextEditingController _qtyController = TextEditingController(text: '10');
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
    StorageService().activeTokoNotifier.addListener(_onTokoChanged);
  }

  @override
  void dispose() {
    StorageService().activeTokoNotifier.removeListener(_onTokoChanged);
    _qtyController.dispose();
    super.dispose();
  }

  void _onTokoChanged() {
    if (mounted) {
      _loadData();
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final items = await StorageService().loadItems();
    setState(() {
      _allItems = items;
      _isLoading = false;

      // Pertahankan item yang terpilih atau pilih item pertama / item menipis
      if (_selectedItem != null) {
        _selectedItem = _allItems.firstWhere(
          (i) => i.id == _selectedItem!.id,
          orElse: () => _allItems.isNotEmpty ? _allItems.first : _selectedItem!,
        );
      } else if (_allItems.isNotEmpty) {
        final menipisFirst = _allItems.firstWhere(
          (i) => i.status == ItemStatus.menipis,
          orElse: () => _allItems.first,
        );
        _selectedItem = menipisFirst;
      }
    });
  }

  List<ItemModel> get _menipisItems =>
      _allItems.where((i) => i.status == ItemStatus.menipis).toList();

  String _formatStock(double val) {
    return val % 1 == 0 ? val.toInt().toString() : val.toStringAsFixed(1);
  }

  // ==========================================
  // SMART RESTOCK & OVERSTOCK LOGIC
  // ==========================================
  Future<void> _handleVerifyRestock() async {
    if (_selectedItem == null) return;

    final requestedQty = double.tryParse(_qtyController.text) ?? 0.0;
    if (requestedQty <= 0) {
      AudioService().playWarning();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Masukkan kuantitas kulakan yang valid (> 0)!'),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
      return;
    }

    final item = _selectedItem!;
    final bool isOverstocked = item.status == ItemStatus.overstock;
    final bool willOverflow = (item.stock + requestedQty) > (item.maxStock * 1.1);

    // Jika terdeteksi risiko overstock / penumpukan modal
    if (isOverstocked || willOverflow) {
      // Audio feedback: WARNING
      await AudioService().playWarning();
      if (!mounted) return;
      _showOverstockWarningDialog(item, requestedQty);
    } else {
      // Aman: langsung jalankan restock
      await _executeRestock(item, requestedQty);
    }
  }

  Future<void> _executeRestock(ItemModel item, double qty) async {
    final updated = await StorageService().adjustStockDelta(
      item.id,
      qty,
      customAction: 'Kulakan Restock',
    );

    if (updated != null) {
      await AudioService().playSuccess();
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Restock Berhasil: ${item.name} bertambah +${_formatStock(qty)} ${item.unit}'),
          backgroundColor: const Color(0xFF10B981),
        ),
      );

      _loadData();
    }
  }

  // ==========================================
  // MODAL MERAH PERINGATAN OVERSTOCK
  // ==========================================
  void _showOverstockWarningDialog(ItemModel item, double requestedQty) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        contentPadding: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: Color(0xFFDC2626), width: 2.0),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header Banner Merah
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFDC2626), Color(0xFF991B1B)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
              ),
              child: Column(
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(LucideIcons.alertTriangle, color: Color(0xFFDC2626), size: 30),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'SMART RESTOCK SHIELD',
                      style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'PERINGATAN OVERSTOCK!',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),

            // Konten Peringatan & Detail Perhitungan
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  // Penjelasan Bahaya Modal Macet
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDC2626).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFDC2626).withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Stok barang ini masih menumpuk di warung!',
                          style: TextStyle(
                            color: Color(0xFFFCA5A5),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Sisa stok di etalase sudah mendekati atau melebihi batas aman maksimal. Mengeluarkan modal untuk kulakan barang ini tidak efisien dan berisiko barang kedaluwarsa.',
                          style: TextStyle(color: Color(0xFFE2E8F0), fontSize: 11, height: 1.3),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Tabel Rincian Angka Kapasitas
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        _buildModalRow('Nama Komoditas:', item.name, isBold: true),
                        const Divider(color: Color(0xFF334155), height: 12),
                        _buildModalRow('Sisa Stok Saat Ini:', '${_formatStock(item.stock)} ${item.unit}', valueColor: const Color(0xFFF87171), isBold: true),
                        const Divider(color: Color(0xFF334155), height: 12),
                        _buildModalRow('Batas Maksimal Gudang:', '${_formatStock(item.maxStock)} ${item.unit}'),
                        const Divider(color: Color(0xFF334155), height: 12),
                        _buildModalRow('Rencana Kulakan Baru:', '+${_formatStock(requestedQty)} ${item.unit}', isBold: true),
                        const Divider(color: Color(0xFF334155), height: 12),
                        _buildModalRow(
                          'Potensi Total Stok:',
                          '${_formatStock(item.stock + requestedQty)} ${item.unit}',
                          valueColor: const Color(0xFFEF4444),
                          isBold: true,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Tombol Aksi: Tunda vs Paksa
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(LucideIcons.shieldCheck, size: 16),
                      label: const Text('Saya Mengerti (Tunda Kulakan)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFDC2626),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _executeRestock(item, requestedQty);
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF94A3B8),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                      child: const Text('Tetap Paksa Kulakan (Abaikan Peringatan)', style: TextStyle(fontSize: 11)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModalRow(String label, String value, {Color? valueColor, bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? Colors.white,
            fontSize: 11.5,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  // ==========================================
  // WIDGET BUILDER
  // ==========================================
  @override
  Widget build(BuildContext context) {
    final menipisList = _menipisItems;

    return Scaffold(
      backgroundColor: const Color(0xFF020617), // slate-950
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF10B981)))
          : RefreshIndicator(
              onRefresh: _loadData,
              color: const Color(0xFF10B981),
              backgroundColor: const Color(0xFF0F172A),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(14.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. KARTU REKAP KULAKAN: WAJIB KULAK (STOK MENIPIS)
                    _buildWajibKulakCard(menipisList),

                    const SizedBox(height: 16),

                    // 2. FORM PERENCANAAN KULAKAN BARANG
                    _buildRestockPlannerForm(),

                    const SizedBox(height: 16),

                    // 3. TIPS RISET SMART RESTOCK
                    _buildResearchInfoBanner(),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildWajibKulakCard(List<ItemModel> menipisList) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A), // slate-900
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(LucideIcons.alertCircle, color: Color(0xFFF59E0B), size: 18),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Wajib Kulak (Stok Menipis)',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13.5),
                      ),
                      Text(
                        'Cabang: ${StorageService().activeTokoName} • Di bawah batas minimum',
                        style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 10),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${menipisList.length} Barang',
                  style: const TextStyle(color: Color(0xFFF59E0B), fontWeight: FontWeight.bold, fontSize: 10.5),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          if (menipisList.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 20),
              alignment: Alignment.center,
              child: Column(
                children: const [
                  Icon(LucideIcons.checkCircle2, color: Color(0xFF10B981), size: 36),
                  SizedBox(height: 6),
                  Text(
                    'Semua stok aman!',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  Text(
                    'Tidak ada komoditas di bawah batas minimum saat ini.',
                    style: TextStyle(color: Color(0xFF64748B), fontSize: 10.5),
                  ),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: menipisList.length,
              separatorBuilder: (_, __) => const Divider(color: Color(0xFF1E293B), height: 12),
              itemBuilder: (context, index) {
                final item = menipisList[index];
                final isSelected = _selectedItem?.id == item.id;
                final defisit = (item.maxStock - item.stock);

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFFF59E0B).withOpacity(0.08) : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: isSelected ? Border.all(color: const Color(0xFFF59E0B).withOpacity(0.3)) : null,
                  ),
                  child: Row(
                    children: [
                      Text(item.img, style: const TextStyle(fontSize: 20)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.name,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              'Sisa: ${_formatStock(item.stock)} ${item.unit}  (Min: ${_formatStock(item.minStock)})',
                              style: const TextStyle(color: Color(0xFFF59E0B), fontSize: 10, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _selectedItem = item;
                            _qtyController.text = _formatStock(defisit > 0 ? defisit : item.minStock);
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isSelected ? const Color(0xFFF59E0B) : const Color(0xFF1E293B),
                          foregroundColor: isSelected ? Colors.black : const Color(0xFFF59E0B),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          elevation: 0,
                        ),
                        child: Text(
                          isSelected ? 'Terpilih' : 'Kulak Ini',
                          style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildRestockPlannerForm() {
    final item = _selectedItem;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF1E293B)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(LucideIcons.clipboardList, color: Color(0xFF10B981), size: 18),
              SizedBox(width: 8),
              Text(
                'Form Perencanaan Kulakan',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Dropdown Pilih Produk
          const Text('Pilih Produk yang Hendak Dikulak:', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<ItemModel>(
                value: item,
                isExpanded: true,
                dropdownColor: const Color(0xFF1E293B),
                style: const TextStyle(color: Colors.white, fontSize: 12),
                items: _allItems.map((i) {
                  return DropdownMenuItem<ItemModel>(
                    value: i,
                    child: Text(
                      '${i.img} ${i.name} (${i.statusLabel.toUpperCase()} - Sisa: ${_formatStock(i.stock)} ${i.unit})',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _selectedItem = val;
                      final defisit = val.maxStock - val.stock;
                      _qtyController.text = _formatStock(defisit > 0 ? defisit : 10.0);
                    });
                  }
                },
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Live Card Detail Produk Terpilih
          if (item != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF020617),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF1E293B)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          item.name,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: item.statusBgColor,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          item.statusLabel.toUpperCase(),
                          style: TextStyle(
                            color: item.statusTextColor,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Grid 3 Kotak (Stok, Min, Max)
                  Row(
                    children: [
                      _buildDetailBox('Stok Saat Ini', '${_formatStock(item.stock)} ${item.unit}'),
                      const SizedBox(width: 6),
                      _buildDetailBox('Batas Min', '${_formatStock(item.minStock)} ${item.unit}'),
                      const SizedBox(width: 6),
                      _buildDetailBox('Batas Maks', '${_formatStock(item.maxStock)} ${item.unit}'),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // Progress Bar Kapasitas
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: item.capacityPercentage,
                      backgroundColor: const Color(0xFF1E293B),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        item.status == ItemStatus.overstock
                            ? const Color(0xFFEF4444)
                            : (item.status == ItemStatus.menipis
                                ? const Color(0xFFF59E0B)
                                : const Color(0xFF10B981)),
                      ),
                      minHeight: 6,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],

          // Input Rencana Kuantitas Kulakan Baru
          const Text('Rencana Jumlah Pesanan / Kulakan Baru:', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF334155)),
                  ),
                  child: TextField(
                    controller: _qtyController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                child: Text(
                  item?.unit ?? 'pcs',
                  style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Tombol Verifikasi & Proses Kulakan
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: item == null ? null : _handleVerifyRestock,
              icon: const Icon(LucideIcons.checkCircle, size: 16),
              label: const Text('Verifikasi & Proses Kulakan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
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
    );
  }

  Widget _buildDetailBox(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(label, style: const TextStyle(color: Color(0xFF64748B), fontSize: 9.5)),
            const SizedBox(height: 2),
            Text(
              value,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResearchInfoBanner() {
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
          const Icon(LucideIcons.shieldAlert, color: Color(0xFF10B981), size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Smart Restock & Overstock Protection',
                  style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 12),
                ),
                SizedBox(height: 2),
                Text(
                  'Sistem secara otomatis mencegah pemborosan modal dengan menghalau kulakan jika stok masih menumpuk di etalase toko.',
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
