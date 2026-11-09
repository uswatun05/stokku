import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/item_model.dart';
import '../models/activity_log_model.dart';

class StorageService {
  static const String _keyInventory = 'smartstock_inventory';
  static const String _keyLogs = 'smartstock_logs';
  static const String _keyAudioMuted = 'smartstock_audio_muted';
  static const String _keyActiveToko = 'smartstock_active_toko';

  // Daftar Cabang / Outlet yang Didukung
  static const String defaultTokoId = 'Toko Pusat';
  static const List<String> availableTokoList = [
    'Toko Pusat',
    'Cabang 1',
    'Cabang 2',
  ];

  // Singleton pattern
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  // In-memory state cache untuk performa responsif
  List<ItemModel> _inventoryCache = [];
  List<ActivityLogModel> _logsCache = [];
  bool _isInitialized = false;

  // State Cabang Aktif
  String _activeTokoId = defaultTokoId;
  String get activeTokoId => _activeTokoId;
  String get activeTokoName => _activeTokoId;

  /// Notifier agar widget dapat merender ulang otomatis saat cabang aktif berganti
  final ValueNotifier<String> activeTokoNotifier = ValueNotifier<String>(defaultTokoId);

  /// Mengambil daftar stok yang telah difilter berdasarkan toko aktif saat ini
  List<ItemModel> get inventory => List.unmodifiable(getItems());

  /// Seluruh inventaris tanpa filter toko (untuk kebutuhan agregasi/admin)
  List<ItemModel> get allInventory => List.unmodifiable(_inventoryCache);

  List<ActivityLogModel> get logs => List.unmodifiable(_logsCache);

  // ==========================================
  // 1. INITIALIZATION & SYNC
  // ==========================================
  Future<void> init() async {
    if (_isInitialized) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload(); // Pastikan sinkron dengan disk
    _activeTokoId = prefs.getString(_keyActiveToko) ?? defaultTokoId;
    activeTokoNotifier.value = _activeTokoId;

    await loadItems();
    await loadLogs();
    _isInitialized = true;
  }

  /// Mengubah Cabang / Toko Aktif
  Future<void> setActiveToko(String tokoId) async {
    if (!availableTokoList.contains(tokoId)) {
      _activeTokoId = defaultTokoId;
    } else {
      _activeTokoId = tokoId;
    }
    activeTokoNotifier.value = _activeTokoId;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyActiveToko, _activeTokoId);
  }

  // ==========================================
  // 2. PERSISTENT STORAGE: LOAD & SAVE ITEMS
  // ==========================================

  /// Mengambil seluruh data stok JSON dari SharedPreferences secara permanen,
  /// melakukan decode menjadi List<ItemModel>, dan memasukkan ke dalam state _inventoryCache.
  /// Mengembalikan list item yang telah difilter sesuai tokoId (default: activeTokoId).
  Future<List<ItemModel>> loadItems({String? tokoId}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload(); // Membaca data terbaru dari disk lokal
    final String? jsonStr = prefs.getString(_keyInventory);

    if (jsonStr != null && jsonStr.trim().isNotEmpty) {
      try {
        final List<dynamic> decoded = jsonDecode(jsonStr);
        _inventoryCache = decoded
            .map((e) => ItemModel.fromJson(e as Map<String, dynamic>))
            .toList();

        // Pastikan cabang 1 dan cabang 2 memiliki sampel data awal jika belum pernah ada
        final hasCabang1 = _inventoryCache.any((i) => i.tokoId == 'Cabang 1');
        final hasCabang2 = _inventoryCache.any((i) => i.tokoId == 'Cabang 2');
        if (!hasCabang1 || !hasCabang2) {
          final missingDefaults = ItemModel.defaultInventory.where((def) {
            return !_inventoryCache.any((cached) => cached.id == def.id);
          });
          if (missingDefaults.isNotEmpty) {
            _inventoryCache.addAll(missingDefaults);
            await saveItems();
          }
        }
      } catch (e) {
        debugPrint('Gagal membaca data JSON lokal: $e');
        _inventoryCache = List.from(ItemModel.defaultInventory);
        await saveItems();
      }
    } else {
      // Pertama kali aplikasi dijalankan (belum ada database lokal)
      _inventoryCache = List.from(ItemModel.defaultInventory);
      await saveItems();
    }

    return getItems(tokoId: tokoId);
  }

  /// Alias loadInventory mengarah ke loadItems agar kompatibel dengan pemanggilan sebelumnya
  Future<List<ItemModel>> loadInventory({String? tokoId}) => loadItems(tokoId: tokoId);

  /// Meng-encode seluruh daftar barang (List<ItemModel>) menjadi format JSON
  /// dan menyimpannya secara permanen ke database lokal SharedPreferences.
  Future<bool> saveItems([List<ItemModel>? items]) async {
    final prefs = await SharedPreferences.getInstance();
    if (items != null) {
      _inventoryCache = List.from(items);
    }
    final List<Map<String, dynamic>> mapList =
        _inventoryCache.map((e) => e.toJson()).toList();
    final String encoded = jsonEncode(mapList);
    return await prefs.setString(_keyInventory, encoded);
  }

  /// Alias saveInventory mengarah ke saveItems
  Future<bool> saveInventory(List<ItemModel> items) => saveItems(items);

  /// Mengambil stok yang telah difilter berdasarkan tokoId (default: activeTokoId)
  List<ItemModel> getItems({String? tokoId}) {
    final target = tokoId ?? _activeTokoId;
    return _inventoryCache.where((i) => i.tokoId == target).toList();
  }

  /// Mencari barang berdasarkan ID dengan memprioritaskan toko aktif
  ItemModel? getItemById(String id, {String? tokoId}) {
    final target = tokoId ?? _activeTokoId;
    try {
      return _inventoryCache.firstWhere((i) => i.id == id && i.tokoId == target);
    } catch (_) {
      try {
        return _inventoryCache.firstWhere((i) => i.id == id);
      } catch (_) {
        return null;
      }
    }
  }

  /// Mencari barang berdasarkan Barcode dengan memprioritaskan toko aktif
  ItemModel? getItemByBarcode(String barcode, {String? tokoId}) {
    final target = tokoId ?? _activeTokoId;
    final cleanBarcode = barcode.trim().toUpperCase();
    try {
      return _inventoryCache.firstWhere(
        (i) => i.barcode.trim().toUpperCase() == cleanBarcode && i.tokoId == target,
      );
    } catch (_) {
      try {
        return _inventoryCache.firstWhere(
          (i) => i.barcode.trim().toUpperCase() == cleanBarcode,
        );
      } catch (_) {
        return null;
      }
    }
  }

  /// Menambah barang baru ke dalam stok (Otomatis menyisipkan activeTokoId dan simpan permanen)
  Future<bool> addItem(ItemModel newItem) async {
    final targetToko = newItem.tokoId.isNotEmpty ? newItem.tokoId : _activeTokoId;
    final itemWithToko = newItem.copyWith(tokoId: targetToko);

    // Otomatis buat barcode unik jika kosong atau dummy agar tidak terjadi tabrakan
    String cleanBarcode = itemWithToko.barcode.trim().toUpperCase();
    if (cleanBarcode.isEmpty || cleanBarcode == '0000000000') {
      cleanBarcode = generateDefaultBarcode(tokoId: targetToko);
    }
    final finalizedItem = itemWithToko.copyWith(barcode: cleanBarcode);

    // Validasi apakah barcode sudah pernah dipakai barang lain di toko yang sama
    final exists = _inventoryCache.any(
      (i) => i.barcode.trim().toUpperCase() == cleanBarcode && i.tokoId == targetToko,
    );
    if (exists) {
      debugPrint('Barcode $cleanBarcode sudah ada di $targetToko');
      return false;
    }

    _inventoryCache.add(finalizedItem);
    final success = await saveItems();
    if (success) {
      await addLog(
        'Tambah Barang',
        '${finalizedItem.name} (+${finalizedItem.stock} ${finalizedItem.unit}) didaftarkan di [$targetToko].',
        type: 'success',
      );
    }
    return success;
  }

  /// Memperbarui informasi barang yang sudah ada dan simpan permanen
  Future<bool> updateItem(ItemModel updatedItem) async {
    final index = _inventoryCache.indexWhere(
      (i) => i.id == updatedItem.id && i.tokoId == updatedItem.tokoId,
    );
    final targetIndex = index != -1 ? index : _inventoryCache.indexWhere((i) => i.id == updatedItem.id);
    if (targetIndex == -1) return false;

    _inventoryCache[targetIndex] = updatedItem;
    final success = await saveItems();
    if (success) {
      await addLog(
        'Update Produk',
        'Data ${updatedItem.name} [${updatedItem.tokoId}] berhasil diperbarui.',
        type: 'info',
      );
    }
    return success;
  }

  /// Menghapus barang dari daftar stok dan simpan permanen
  Future<bool> deleteItem(String id, {String? tokoId}) async {
    final item = getItemById(id, tokoId: tokoId);
    if (item == null) return false;

    _inventoryCache.removeWhere((i) => i.id == id && i.tokoId == item.tokoId);
    final success = await saveItems();
    if (success) {
      await addLog(
        'Hapus Barang',
        '${item.name} dihapus permanen dari sistem [${item.tokoId}].',
        type: 'danger',
      );
    }
    return success;
  }

  /// Mutasi cepat penambahan/pengurangan kuantitas stok (+/- delta) dan simpan permanen
  Future<ItemModel?> adjustStockDelta(String id, double delta, {String? customAction, String? tokoId}) async {
    final item = getItemById(id, tokoId: tokoId);
    if (item == null) return null;

    final double newStock = max(0.0, item.stock + delta);
    final updatedItem = item.copyWith(stock: newStock);
    final index = _inventoryCache.indexWhere(
      (i) => i.id == updatedItem.id && i.tokoId == updatedItem.tokoId,
    );
    if (index != -1) {
      _inventoryCache[index] = updatedItem;
      final success = await saveItems();
      if (success) {
        final sign = delta >= 0 ? '+' : '';
        final action = customAction ?? (delta < 0 ? 'Penjualan' : 'Restock');
        await addLog(
          action,
          '${item.name} ($sign$delta ${item.unit}) -> Sisa: $newStock ${item.unit} [${item.tokoId}]',
          type: delta < 0 ? 'success' : 'info',
        );
        return updatedItem;
      }
    }
    return null;
  }

  /// Mereset kembali database stok ke data awal multi-cabang
  Future<bool> resetToDefault() async {
    final success = await saveItems(ItemModel.defaultInventory);
    if (success) {
      await addLog('Reset Database', 'Database inventaris dikembalikan ke data awal multi-cabang.', type: 'warning');
    }
    return success;
  }

  // ==========================================
  // 3. GENERATOR KODE OTOMATIS
  // ==========================================

  /// Membuat barcode unik acak untuk barang curah: misal "CRH-8492"
  String generateCurahBarcode({String? tokoId}) {
    final target = tokoId ?? _activeTokoId;
    final random = Random();
    String code = '';
    bool exists = true;
    int attempts = 0;

    while (exists && attempts < 100) {
      attempts++;
      final num = 1000 + random.nextInt(9000);
      code = 'CRH-$num';
      exists = _inventoryCache.any((i) => i.barcode.trim().toUpperCase() == code && i.tokoId == target);
    }

    return code.isNotEmpty ? code : 'CRH-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}';
  }

  /// Membuat barcode default unik untuk barang kemasan jika barcode tidak diinput: misal "PKG-4512"
  String generateDefaultBarcode({String? tokoId}) {
    final target = tokoId ?? _activeTokoId;
    final random = Random();
    String code = '';
    bool exists = true;
    int attempts = 0;

    while (exists && attempts < 100) {
      attempts++;
      final num = 1000 + random.nextInt(9000);
      code = 'PKG-$num';
      exists = _inventoryCache.any((i) => i.barcode.trim().toUpperCase() == code && i.tokoId == target);
    }

    return code.isNotEmpty ? code : 'PKG-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
  }

  /// Menghasilkan ID berikutnya secara berurutan: misal "BRG-012"
  String generateNextItemId() {
    int maxNum = 0;
    for (final item in _inventoryCache) {
      if (item.id.startsWith('BRG-')) {
        final parsed = int.tryParse(item.id.replaceAll('BRG-', '')) ?? 0;
        if (parsed > maxNum) maxNum = parsed;
      }
    }
    return 'BRG-${(maxNum + 1).toString().padLeft(3, '0')}';
  }

  // ==========================================
  // 4. ACTIVITY LOGS OPERATIONS
  // ==========================================

  Future<List<ActivityLogModel>> loadLogs() async {
    final prefs = await SharedPreferences.getInstance();
    final String? jsonStr = prefs.getString(_keyLogs);

    if (jsonStr != null && jsonStr.isNotEmpty) {
      try {
        final List<dynamic> decoded = jsonDecode(jsonStr);
        _logsCache = decoded.map((e) => ActivityLogModel.fromJson(e as Map<String, dynamic>)).toList();
      } catch (_) {
        _logsCache = [];
      }
    } else {
      _logsCache = [];
    }
    return _logsCache;
  }

  Future<bool> addLog(String action, String description, {String type = 'info'}) async {
    final newLog = ActivityLogModel(
      id: 'LOG-${DateTime.now().millisecondsSinceEpoch}',
      timestamp: DateTime.now(),
      action: action,
      description: description,
      type: type,
    );

    // Sisipkan log terbaru di posisi paling atas (index 0)
    final updated = List<ActivityLogModel>.from(_logsCache)..insert(0, newLog);
    // Batasi riwayat log maksimal 100 entri agar hemat memori
    if (updated.length > 100) {
      updated.removeRange(100, updated.length);
    }

    _logsCache = updated;
    final prefs = await SharedPreferences.getInstance();
    return await prefs.setString(_keyLogs, jsonEncode(_logsCache.map((e) => e.toJson()).toList()));
  }

  Future<bool> clearLogs() async {
    _logsCache = [];
    final prefs = await SharedPreferences.getInstance();
    return await prefs.remove(_keyLogs);
  }

  // ==========================================
  // 5. AUDIO PREFERENCE OPERATIONS
  // ==========================================

  Future<bool> isAudioMuted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyAudioMuted) ?? false;
  }

  Future<bool> setAudioMuted(bool isMuted) async {
    final prefs = await SharedPreferences.getInstance();
    return await prefs.setBool(_keyAudioMuted, isMuted);
  }
}
