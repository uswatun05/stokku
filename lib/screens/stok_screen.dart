import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../models/item_model.dart';
import '../services/storage_service.dart';
import '../services/audio_service.dart';
import '../widgets/item_card.dart';

class StokScreen extends StatefulWidget {
  const StokScreen({super.key});

  @override
  State<StokScreen> createState() => _StokScreenState();
}

class _StokScreenState extends State<StokScreen> {
  List<ItemModel> _allItems = [];
  bool _isLoading = true;

  // Search & Filter
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedCategory = 'Semua';

  final List<String> _categories = [
    'Semua',
    'Sembako Curah',
    'Sembako',
    'Makanan Instan',
    'Minuman',
    'Bumbu Dapur',
    'Rokok',
    'Perawatan Tubuh',
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final items = await StorageService().loadInventory();
    setState(() {
      _allItems = items;
      _isLoading = false;
    });
  }

  List<ItemModel> get _filteredItems {
    return _allItems.where((item) {
      final matchesSearch = item.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          item.barcode.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesCategory = _selectedCategory == 'Semua' || item.category == _selectedCategory;
      return matchesSearch && matchesCategory;
    }).toList();
  }

  int get _menipisCount => _allItems.where((i) => i.status == ItemStatus.menipis).length;
  int get _overstockCount => _allItems.where((i) => i.status == ItemStatus.overstock).length;

  // ==========================================
  // QUICK STOCK ADJUSTMENT (+/-)
  // ==========================================
  Future<void> _handleStockDelta(String id, double delta) async {
    final updated = await StorageService().adjustStockDelta(id, delta);
    if (updated != null) {
      await AudioService().playSuccess();
      _loadData();
    }
  }

  // ==========================================
  // MODAL / DIALOG: TAMBAH BARANG BARU
  // ==========================================
  void _openAddProductDialog() {
    final nameCtrl = TextEditingController();
    final barcodeCtrl = TextEditingController();
    final stockCtrl = TextEditingController(text: '10');
    final minCtrl = TextEditingController(text: '5');
    final maxCtrl = TextEditingController(text: '30');
    final unitCtrl = TextEditingController(text: 'pcs');
    final priceCtrl = TextEditingController(text: '5000');
    String selectedType = 'barcode';
    String selectedCat = 'Sembako';
    String selectedEmoji = '📦';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF0F172A),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: const BorderSide(color: Color(0xFF10B981), width: 1.2),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(LucideIcons.packagePlus, color: Color(0xFF10B981), size: 20),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Tambah Barang Baru',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Tipe Barang: Barcode vs Curah
                  const Text('Tipe Komoditas:', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: const Text('Kemasan Barcode'),
                          selected: selectedType == 'barcode',
                          selectedColor: const Color(0xFF10B981),
                          backgroundColor: const Color(0xFF1E293B),
                          labelStyle: TextStyle(
                            color: selectedType == 'barcode' ? Colors.black : Colors.white70,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                          onSelected: (val) {
                            if (val) {
                              setDialogState(() {
                                selectedType = 'barcode';
                                barcodeCtrl.clear();
                                selectedEmoji = '📦';
                              });
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ChoiceChip(
                          label: const Text('Curah (AI Vision)'),
                          selected: selectedType == 'curah',
                          selectedColor: const Color(0xFF818CF8),
                          backgroundColor: const Color(0xFF1E293B),
                          labelStyle: TextStyle(
                            color: selectedType == 'curah' ? Colors.black : Colors.white70,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                          onSelected: (val) {
                            if (val) {
                              setDialogState(() {
                                selectedType = 'curah';
                                barcodeCtrl.text = StorageService().generateCurahBarcode();
                                unitCtrl.text = 'kg';
                                selectedEmoji = '🌾';
                              });
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Nama Barang
                  _buildDialogTextField('Nama Barang', nameCtrl, hint: 'Misal: Telur Curah / Sabun Mandi'),
                  const SizedBox(height: 10),

                  // Barcode (Auto-generate if curah)
                  Row(
                    children: [
                      Expanded(
                        child: _buildDialogTextField(
                          'Kode Barcode',
                          barcodeCtrl,
                          hint: 'Kode EAN / UPC / CRH',
                        ),
                      ),
                      if (selectedType == 'curah') ...[
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(LucideIcons.refreshCw, color: Color(0xFF818CF8), size: 18),
                          tooltip: 'Generate Barcode Curah Baru',
                          onPressed: () {
                            setDialogState(() {
                              barcodeCtrl.text = StorageService().generateCurahBarcode();
                            });
                          },
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Kategori & Emoji
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Kategori:', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E293B),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFF334155)),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: selectedCat,
                                  isExpanded: true,
                                  dropdownColor: const Color(0xFF1E293B),
                                  style: const TextStyle(color: Colors.white, fontSize: 12),
                                  items: _categories
                                      .where((c) => c != 'Semua')
                                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                                      .toList(),
                                  onChanged: (val) {
                                    if (val != null) setDialogState(() => selectedCat = val);
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: _buildDialogTextField('Satuan', unitCtrl, hint: 'pcs/kg/liter'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Stok Awal & Harga
                  Row(
                    children: [
                      Expanded(
                        child: _buildDialogTextField('Stok Awal', stockCtrl, keyboardType: TextInputType.number),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildDialogTextField('Harga (Rp)', priceCtrl, keyboardType: TextInputType.number),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Batas Min (Alert) & Batas Max (Overstock)
                  Row(
                    children: [
                      Expanded(
                        child: _buildDialogTextField('Batas Min (Alert)', minCtrl, keyboardType: TextInputType.number),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildDialogTextField('Batas Max (Gudang)', maxCtrl, keyboardType: TextInputType.number),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Batal', style: TextStyle(color: Color(0xFF94A3B8))),
              ),
              ElevatedButton(
                onPressed: () async {
                  final name = nameCtrl.text.trim();
                  if (name.isEmpty) return;

                  final newItem = ItemModel(
                    id: StorageService().generateNextItemId(),
                    name: name,
                    type: selectedType,
                    barcode: barcodeCtrl.text.trim().isNotEmpty
                        ? barcodeCtrl.text.trim()
                        : (selectedType == 'curah' ? StorageService().generateCurahBarcode() : '000000000000'),
                    category: selectedCat,
                    stock: double.tryParse(stockCtrl.text) ?? 10.0,
                    minStock: double.tryParse(minCtrl.text) ?? 5.0,
                    maxStock: double.tryParse(maxCtrl.text) ?? 30.0,
                    unit: unitCtrl.text.trim().isNotEmpty ? unitCtrl.text.trim() : 'pcs',
                    price: double.tryParse(priceCtrl.text) ?? 5000.0,
                    img: selectedEmoji,
                  );

                  final success = await StorageService().addItem(newItem);
                  if (success) {
                    await AudioService().playSuccess();
                    if (!mounted) return;
                    Navigator.pop(ctx);
                    _loadData();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('✅ ${newItem.name} berhasil ditambahkan ke inventaris.'),
                        backgroundColor: const Color(0xFF10B981),
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Simpan Barang', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  // ==========================================
  // MODAL / DIALOG: EDIT BARANG
  // ==========================================
  void _openEditProductDialog(ItemModel item) {
    final nameCtrl = TextEditingController(text: item.name);
    final stockCtrl = TextEditingController(text: item.stock % 1 == 0 ? item.stock.toInt().toString() : item.stock.toString());
    final minCtrl = TextEditingController(text: item.minStock.toInt().toString());
    final maxCtrl = TextEditingController(text: item.maxStock.toInt().toString());
    final priceCtrl = TextEditingController(text: item.price.toInt().toString());
    String selectedCat = item.category;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF0F172A),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: const BorderSide(color: Color(0xFF38BDF8), width: 1.2),
            ),
            title: Row(
              children: [
                const Icon(LucideIcons.edit2, color: Color(0xFF38BDF8), size: 20),
                const SizedBox(width: 10),
                const Text(
                  'Edit Data Produk',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDialogTextField('Nama Barang', nameCtrl),
                  const SizedBox(height: 10),
                  const Text('Kategori:', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF334155)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _categories.contains(selectedCat) ? selectedCat : 'Sembako',
                        isExpanded: true,
                        dropdownColor: const Color(0xFF1E293B),
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                        items: _categories
                            .where((c) => c != 'Semua')
                            .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) setDialogState(() => selectedCat = val);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _buildDialogTextField('Stok Saat Ini (${item.unit})', stockCtrl, keyboardType: TextInputType.number),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildDialogTextField('Harga (Rp)', priceCtrl, keyboardType: TextInputType.number),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _buildDialogTextField('Batas Min', minCtrl, keyboardType: TextInputType.number),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildDialogTextField('Batas Max', maxCtrl, keyboardType: TextInputType.number),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Batal', style: TextStyle(color: Color(0xFF94A3B8))),
              ),
              ElevatedButton(
                onPressed: () async {
                  final updatedItem = item.copyWith(
                    name: nameCtrl.text.trim(),
                    category: selectedCat,
                    stock: double.tryParse(stockCtrl.text) ?? item.stock,
                    price: double.tryParse(priceCtrl.text) ?? item.price,
                    minStock: double.tryParse(minCtrl.text) ?? item.minStock,
                    maxStock: double.tryParse(maxCtrl.text) ?? item.maxStock,
                  );

                  await StorageService().updateItem(updatedItem);
                  await AudioService().playSuccess();
                  if (!mounted) return;
                  Navigator.pop(ctx);
                  _loadData();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF38BDF8),
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Perbarui', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  // ==========================================
  // CONFIRMATION DIALOG: HAPUS BARANG
  // ==========================================
  void _confirmDeleteProduct(ItemModel item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFFEF4444)),
        ),
        title: const Text('Hapus Barang?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text(
          'Yakin ingin menghapus "${item.name}" dari sistem stok inventaris?',
          style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () async {
              await StorageService().deleteItem(item.id);
              await AudioService().playWarning();
              if (!mounted) return;
              Navigator.pop(ctx);
              _loadData();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
            ),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }

  Widget _buildDialogTextField(
    String label,
    TextEditingController controller, {
    String? hint,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF334155)),
          ),
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            style: const TextStyle(color: Colors.white, fontSize: 12),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
              border: InputBorder.none,
              isDense: true,
            ),
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
    final filtered = _filteredItems;

    return Scaffold(
      backgroundColor: const Color(0xFF020617), // slate-950
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF10B981)))
          : RefreshIndicator(
              onRefresh: _loadData,
              color: const Color(0xFF10B981),
              backgroundColor: const Color(0xFF0F172A),
              child: CustomScrollView(
                slivers: [
                  // 1. STATS SUMMARY BAR
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
                      child: _buildStatsSummaryRow(),
                    ),
                  ),

                  // 2. SEARCH BAR
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 6.0),
                      child: _buildSearchBar(),
                    ),
                  ),

                  // 3. HORIZONTAL CATEGORY FILTER PILLS
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 42,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 14.0),
                        itemCount: _categories.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          final cat = _categories[index];
                          final isSelected = cat == _selectedCategory;
                          return ChoiceChip(
                            label: Text(cat),
                            selected: isSelected,
                            selectedColor: const Color(0xFF10B981),
                            backgroundColor: const Color(0xFF0F172A),
                            labelStyle: TextStyle(
                              color: isSelected ? Colors.black : const Color(0xFF94A3B8),
                              fontSize: 11,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: isSelected ? const Color(0xFF10B981) : const Color(0xFF1E293B),
                              ),
                            ),
                            onSelected: (val) {
                              if (val) setState(() => _selectedCategory = cat);
                            },
                          );
                        },
                      ),
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 12)),

                  // 4. LISTVIEW INVENTORY ITEMS
                  if (filtered.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(LucideIcons.packageSearch, color: Color(0xFF334155), size: 48),
                            SizedBox(height: 10),
                            Text(
                              'Tidak ada produk ditemukan',
                              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Coba ganti kata kunci pencarian atau kategori.',
                              style: TextStyle(color: Color(0xFF64748B), fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 14.0),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final item = filtered[index];
                            return ItemCard(
                              item: item,
                              onAdjustStock: (delta) => _handleStockDelta(item.id, delta),
                              onEdit: () => _openEditProductDialog(item),
                              onDelete: () => _confirmDeleteProduct(item),
                              onPrintBarcode: item.isCurah
                                  ? () {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('🖨️ Label Barcode: ${item.name} (${item.barcode}) Siap Dicetak'),
                                          backgroundColor: const Color(0xFF6366F1),
                                        ),
                                      );
                                    }
                                  : null,
                            );
                          },
                          childCount: filtered.length,
                        ),
                      ),
                    ),

                  const SliverToBoxAdapter(child: SizedBox(height: 80)),
                ],
              ),
            ),

      // Floating Action Button: Tambah Barang Baru
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddProductDialog,
        backgroundColor: const Color(0xFF10B981),
        foregroundColor: Colors.black,
        elevation: 6,
        icon: const Icon(LucideIcons.plus, size: 20),
        label: const Text('Tambah Barang', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
      ),
    );
  }

  Widget _buildStatsSummaryRow() {
    return Row(
      children: [
        _buildStatItem(
          label: 'Total SKU',
          value: '${_allItems.length}',
          sub: 'Produk',
          color: const Color(0xFF38BDF8),
          icon: LucideIcons.boxes,
        ),
        const SizedBox(width: 8),
        _buildStatItem(
          label: 'Stok Menipis',
          value: '$_menipisCount',
          sub: 'Wajib Kulak',
          color: const Color(0xFFF59E0B),
          icon: LucideIcons.alertTriangle,
        ),
        const SizedBox(width: 8),
        _buildStatItem(
          label: 'Overstock',
          value: '$_overstockCount',
          sub: 'Tahan Kulak',
          color: const Color(0xFFEF4444),
          icon: LucideIcons.shieldAlert,
        ),
      ],
    );
  }

  Widget _buildStatItem({
    required String label,
    required String value,
    required String sub,
    required Color color,
    required IconData icon,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 12, color: color),
                const SizedBox(width: 4),
                Text(label, style: const TextStyle(color: Color(0xFF64748B), fontSize: 9.5)),
              ],
            ),
            const SizedBox(height: 2),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  value,
                  style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w900),
                ),
                const SizedBox(width: 4),
                Text(
                  sub,
                  style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 9),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1E293B)),
      ),
      child: Row(
        children: [
          const Icon(LucideIcons.search, color: Color(0xFF64748B), size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _searchQuery = val),
              style: const TextStyle(color: Colors.white, fontSize: 12),
              decoration: const InputDecoration(
                hintText: 'Cari nama barang atau barcode...',
                hintStyle: TextStyle(color: Color(0xFF64748B), fontSize: 11),
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
          if (_searchQuery.isNotEmpty)
            IconButton(
              icon: const Icon(LucideIcons.x, color: Color(0xFF64748B), size: 14),
              constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
              padding: EdgeInsets.zero,
              onPressed: () {
                _searchController.clear();
                setState(() => _searchQuery = '');
              },
            ),
        ],
      ),
    );
  }
}
