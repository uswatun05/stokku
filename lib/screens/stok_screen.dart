import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:barcode_widget/barcode_widget.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

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
    'Lainnya',
  ];

  final List<String> _emojiPresets = [
    '📦', '🌾', '🥚', '🧅', '🛢️', '🥜', '🌶️', '🍚', '🥔', '☕',
    '🍜', '🥤', '🧼', '🚬', '🧂', '🍬', '🥛', '🍞',
  ];

  final List<String> _unitPresets = ['pcs', 'kg', 'liter', 'ons', 'gram', 'bungkus', 'botol', 'kaleng', 'ikat'];

  @override
  void initState() {
    super.initState();
    _loadData();
    StorageService().activeTokoNotifier.addListener(_onTokoChanged);
  }

  @override
  void dispose() {
    StorageService().activeTokoNotifier.removeListener(_onTokoChanged);
    _searchController.dispose();
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
  // GENERATOR KODE BARCODE UNIK OTOMATIS
  // ==========================================
  String _generateUniqueBarcode() {
    final random = Random();
    String code;
    bool exists;
    int attempts = 0;

    do {
      attempts++;
      final rand = 1000 + random.nextInt(9000);
      code = 'CRH-$rand';
      exists = _allItems.any((i) => i.barcode.trim().toUpperCase() == code);
    } while (exists && attempts < 50);

    return code;
  }

  // ==========================================
  // CETAK LABEL BARCODE THERMAL PDF (58mm)
  // ==========================================
  Future<void> _printBarcodeLabel(ItemModel item) async {
    try {
      final doc = pw.Document();

      // Format label thermal roll 58mm x 42mm standar POS printer
      const pageFormat = PdfPageFormat(
        58 * PdfPageFormat.mm,
        42 * PdfPageFormat.mm,
        marginAll: 2.0 * PdfPageFormat.mm,
      );

      final currencyFormatter = NumberFormat.currency(
        locale: 'id_ID',
        symbol: 'Rp ',
        decimalDigits: 0,
      );

      doc.addPage(
        pw.Page(
          pageFormat: pageFormat,
          build: (pw.Context context) {
            return pw.Container(
              width: double.infinity,
              height: double.infinity,
              padding: const pw.EdgeInsets.symmetric(horizontal: 2.0, vertical: 2.0),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.black, width: 0.8),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
              ),
              child: pw.Column(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  // Header Toko
                  pw.Column(
                    children: [
                      pw.Text(
                        'StokKu',
                        style: pw.TextStyle(
                          fontSize: 7.0,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(
                        'SmartStock AI • Label Barcode Barang',
                        style: const pw.TextStyle(fontSize: 4.8, color: PdfColors.grey700),
                      ),
                    ],
                  ),

                  pw.Divider(thickness: 0.4, height: 1.5),

                  // Nama Barang & Harga
                  pw.Column(
                    children: [
                      pw.Text(
                        item.name.toUpperCase(),
                        maxLines: 1,
                        textAlign: pw.TextAlign.center,
                        style: pw.TextStyle(
                          fontSize: 7.8,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 0.5),
                      pw.Text(
                        'Satuan: ${item.unit}${item.price > 0 ? " • ${currencyFormatter.format(item.price)}" : ""}',
                        style: const pw.TextStyle(fontSize: 5.5, color: PdfColors.grey800),
                      ),
                    ],
                  ),

                  // Visual Barcode Code128
                  pw.Container(
                    height: 20,
                    width: 46 * PdfPageFormat.mm,
                    child: pw.BarcodeWidget(
                      barcode: pw.Barcode.code128(),
                      data: item.barcode.isNotEmpty ? item.barcode : '0000000000',
                      drawText: true,
                      textStyle: pw.TextStyle(
                        fontSize: 6.0,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),

                  // Footer Waktu Cetak
                  pw.Text(
                    'Dicetak: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
                    style: const pw.TextStyle(fontSize: 4.0, color: PdfColors.grey600),
                  ),
                ],
              ),
            );
          },
        ),
      );

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => doc.save(),
        name: 'Label_${item.name.replaceAll(' ', '_')}_${item.barcode}',
      );
    } catch (e) {
      debugPrint('Gagal cetak label barcode: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('⚠️ Gagal mencetak label: $e'),
          backgroundColor: const Color(0xFFDC2626),
        ),
      );
    }
  }

  // ==========================================
  // MODAL ALERTDIALOG CETAK BARCODE (SETELAH SIMPAN)
  // ==========================================
  void _showBarcodeSuccessDialog(ItemModel item) {
    final currencyFormatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: Color(0xFF10B981), width: 1.5),
        ),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(LucideIcons.checkCircle2, color: Color(0xFF10B981), size: 22),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Barang Berhasil Disimpan!',
                    style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Barcode Otomatis Siap Dicetak',
                    style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Preview Kertas Label Thermal Putih
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const Text(
                      'StokKu',
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const Text(
                      'SmartStock AI • Label Barcode',
                      style: TextStyle(color: Color(0xFF64748B), fontSize: 9),
                    ),
                    const Divider(color: Colors.black26, height: 12, thickness: 1),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(item.img, style: const TextStyle(fontSize: 22)),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            item.name,
                            style: const TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Satuan: ${item.unit} • ${currencyFormatter.format(item.price)}',
                      style: const TextStyle(
                        color: Color(0xFF334155),
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                      ),
                    ),

                    const SizedBox(height: 10),

                    // VISUAL BARCODE MENGGUNAKAN BARCODEWIDGET
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: Colors.black12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: BarcodeWidget(
                        barcode: Barcode.code128(),
                        data: item.barcode.isNotEmpty ? item.barcode : '0000000000',
                        width: 210,
                        height: 65,
                        color: Colors.black,
                        drawText: true,
                        style: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                          letterSpacing: 1.2,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),

                    const SizedBox(height: 6),
                    Text(
                      'Dicetak: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
                      style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 8.5),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                child: Row(
                  children: [
                    const Icon(LucideIcons.printer, color: Color(0xFF10B981), size: 14),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Tempelkan label barcode thermal ini ke toples/wadah ${item.name} agar kasir dapat memindainya langsung.',
                        style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 10.5, height: 1.3),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          Row(
            children: [
              Expanded(
                flex: 2,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF94A3B8),
                    side: const BorderSide(color: Color(0xFF334155)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Tutup / Selesai', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11.5)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 3,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    await _printBarcodeLabel(item);
                  },
                  icon: const Icon(LucideIcons.printer, size: 16),
                  label: const Text(
                    'Cetak Label Barcode',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 2,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

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
  // MODAL / DIALOG: TAMBAH BARANG BARU (DINAMIS)
  // ==========================================
  void _openAddProductDialog() {
    final nameCtrl = TextEditingController();
    final barcodeCtrl = TextEditingController();
    final stockCtrl = TextEditingController(text: '10');
    final minCtrl = TextEditingController(text: '5');
    final maxCtrl = TextEditingController(text: '30');
    final unitCtrl = TextEditingController(text: 'pcs');
    final priceCtrl = TextEditingController(text: '5000');
    String selectedType = 'barcode'; // 'barcode' atau 'curah'
    String selectedCat = 'Sembako';
    String selectedEmoji = '📦';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          final isCurahMode = selectedType == 'curah';

          return AlertDialog(
            backgroundColor: const Color(0xFF0F172A),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: BorderSide(
                color: isCurahMode ? const Color(0xFF818CF8) : const Color(0xFF10B981),
                width: 1.5,
              ),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: (isCurahMode ? const Color(0xFF6366F1) : const Color(0xFF10B981)).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    isCurahMode ? LucideIcons.sparkles : LucideIcons.packagePlus,
                    color: isCurahMode ? const Color(0xFFA5B4FC) : const Color(0xFF10B981),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isCurahMode ? 'Tambah Barang Curah' : 'Tambah Barang Baru',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      Text(
                        isCurahMode ? 'Barcode dibuat & dicetak otomatis' : 'Kemasan dengan barcode pabrik',
                        style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 10.5),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Selector Mode: Kemasan Barcode vs Barang Curah
                  const Text('Pilih Mode Barang:', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: const Text('Barang Kemasan'),
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
                                unitCtrl.text = 'pcs';
                                selectedEmoji = '📦';
                                selectedCat = 'Sembako';
                              });
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ChoiceChip(
                          label: const Text('Barang Curah'),
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
                                barcodeCtrl.text = _generateUniqueBarcode();
                                unitCtrl.text = 'kg';
                                selectedEmoji = '🌾';
                                selectedCat = 'Sembako Curah';
                              });
                            }
                          },
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // 2. Nama Barang
                  _buildDialogTextField(
                    'Nama Barang',
                    nameCtrl,
                    hint: isCurahMode ? 'Misal: Telur Curah / Beras Rojo' : 'Misal: Indomie Goreng / Sabun Lifebuoy',
                  ),

                  const SizedBox(height: 10),

                  // 3. Kolom Barcode Dinamis
                  Row(
                    children: [
                      Expanded(
                        child: _buildDialogTextField(
                          isCurahMode ? 'Kode Barcode Otomatis' : 'Kode Barcode Pabrik',
                          barcodeCtrl,
                          hint: isCurahMode ? 'CRH-XXXX' : 'Scan atau ketik kode barcode kemasan',
                          readOnly: isCurahMode, // Jika curah, barcode terisi otomatis
                        ),
                      ),
                      if (isCurahMode) ...[
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(LucideIcons.refreshCw, color: Color(0xFF818CF8), size: 18),
                          tooltip: 'Generate Barcode Baru',
                          style: IconButton.styleFrom(
                            backgroundColor: const Color(0xFF1E293B),
                            padding: const EdgeInsets.all(8),
                          ),
                          onPressed: () {
                            setDialogState(() {
                              barcodeCtrl.text = _generateUniqueBarcode();
                            });
                          },
                        ),
                      ],
                    ],
                  ),

                  const SizedBox(height: 10),

                  // 4. Kategori & Pilihan Emoji
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
                                  value: _categories.contains(selectedCat) ? selectedCat : 'Lainnya',
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
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Ikon Emoji:', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
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
                                  value: selectedEmoji,
                                  isExpanded: true,
                                  dropdownColor: const Color(0xFF1E293B),
                                  style: const TextStyle(fontSize: 16),
                                  items: _emojiPresets
                                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                                      .toList(),
                                  onChanged: (val) {
                                    if (val != null) setDialogState(() => selectedEmoji = val);
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // 5. Satuan & Stok Awal
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Satuan:', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
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
                                  value: _unitPresets.contains(unitCtrl.text) ? unitCtrl.text : 'pcs',
                                  isExpanded: true,
                                  dropdownColor: const Color(0xFF1E293B),
                                  style: const TextStyle(color: Colors.white, fontSize: 12),
                                  items: _unitPresets
                                      .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                                      .toList(),
                                  onChanged: (val) {
                                    if (val != null) {
                                      setDialogState(() => unitCtrl.text = val);
                                    }
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildDialogTextField(
                          'Stok Awal (${unitCtrl.text})',
                          stockCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // 6. Harga Jual Satuan
                  _buildDialogTextField('Harga Jual (Rp)', priceCtrl, keyboardType: TextInputType.number),

                  const SizedBox(height: 10),

                  // 7. Batas Min (Alert) & Batas Max (Overstock)
                  Row(
                    children: [
                      Expanded(
                        child: _buildDialogTextField(
                          'Batas Min (Alert)',
                          minCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildDialogTextField(
                          'Batas Max (Gudang)',
                          maxCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        ),
                      ),
                    ],
                  ),

                  if (isCurahMode) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.3)),
                      ),
                      child: const Row(
                        children: [
                          Icon(LucideIcons.printer, color: Color(0xFF818CF8), size: 16),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Pop-up cetak label thermal akan otomatis muncul setelah barang curah ini disimpan.',
                              style: TextStyle(color: Color(0xFFC7D2FE), fontSize: 10.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Batal', style: TextStyle(color: Color(0xFF94A3B8))),
              ),
              ElevatedButton.icon(
                onPressed: () async {
                  final name = nameCtrl.text.trim();
                  if (name.isEmpty) {
                    AudioService().playWarning();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Nama barang tidak boleh kosong!'),
                        backgroundColor: Color(0xFFDC2626),
                      ),
                    );
                    return;
                  }

                  String barcode = barcodeCtrl.text.trim();
                  if (barcode.isEmpty) {
                    barcode = isCurahMode
                        ? _generateUniqueBarcode()
                        : StorageService().generateDefaultBarcode();
                  }

                  final newItem = ItemModel(
                    id: StorageService().generateNextItemId(),
                    tokoId: StorageService().activeTokoId,
                    name: name,
                    type: selectedType,
                    barcode: barcode,
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
                    await _loadData();

                    // JIKA BARANG CURAH: TAMPILKAN POP-UP CETAK LABEL BARCODE
                    if (isCurahMode) {
                      _showBarcodeSuccessDialog(newItem);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('✅ ${newItem.name} berhasil disimpan permanen.'),
                          backgroundColor: const Color(0xFF10B981),
                        ),
                      );
                    }
                  } else {
                    await AudioService().playWarning();
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('⚠️ Barcode sudah terdaftar pada barang lain di cabang ini!'),
                        backgroundColor: Color(0xFFDC2626),
                      ),
                    );
                  }
                },
                icon: const Icon(LucideIcons.save, size: 16),
                label: Text(
                  isCurahMode ? 'Simpan & Siapkan Barcode' : 'Simpan Barang',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isCurahMode ? const Color(0xFF6366F1) : const Color(0xFF10B981),
                  foregroundColor: isCurahMode ? Colors.white : Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
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
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(LucideIcons.edit2, color: Color(0xFF38BDF8), size: 20),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Edit Data Barang',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildDialogTextField('Nama Barang', nameCtrl),
                  const SizedBox(height: 10),
                  Column(
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
                            value: _categories.contains(selectedCat) ? selectedCat : 'Lainnya',
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
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _buildDialogTextField(
                          'Stok Saat Ini (${item.unit})',
                          stockCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        ),
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
                        child: _buildDialogTextField(
                          'Batas Min',
                          minCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildDialogTextField(
                          'Batas Max',
                          maxCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        ),
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
    bool readOnly = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
          decoration: BoxDecoration(
            color: readOnly ? const Color(0xFF0F172A) : const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: readOnly ? const Color(0xFF6366F1).withValues(alpha: 0.5) : const Color(0xFF334155)),
          ),
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            readOnly: readOnly,
            style: TextStyle(
              color: readOnly ? const Color(0xFFA5B4FC) : Colors.white,
              fontWeight: readOnly ? FontWeight.bold : FontWeight.normal,
              fontSize: 12,
            ),
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
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
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
                              // Tombol Cetak Barcode Thermal langsung dari kartu produk
                              onPrintBarcode: () => _showBarcodeSuccessDialog(item),
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
    return Column(
      children: [
        // Indikator Cabang Aktif
        Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF1E293B)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(LucideIcons.mapPin, color: Color(0xFF10B981), size: 14),
                  const SizedBox(width: 6),
                  Text(
                    'Cabang Aktif: ${StorageService().activeTokoName}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${_allItems.length} SKU',
                  style: const TextStyle(
                    color: Color(0xFF6EE7B7),
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Row Statistik Produk (Total SKU, Menipis, Overstock)
        Row(
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
              sub: 'Tunda Kulak',
              color: const Color(0xFFEF4444),
              icon: LucideIcons.alertOctagon,
            ),
          ],
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
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(label, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 10)),
                Icon(icon, size: 14, color: color),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(sub, style: const TextStyle(color: Color(0xFF64748B), fontSize: 9.5)),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1E293B)),
      ),
      child: TextField(
        controller: _searchController,
        style: const TextStyle(color: Colors.white, fontSize: 13),
        onChanged: (val) {
          setState(() {
            _searchQuery = val.trim();
          });
        },
        decoration: InputDecoration(
          hintText: 'Cari nama produk atau kode barcode...',
          hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
          prefixIcon: const Icon(LucideIcons.search, color: Color(0xFF10B981), size: 18),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(LucideIcons.x, size: 16, color: Color(0xFF94A3B8)),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _searchQuery = '';
                    });
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }
}
