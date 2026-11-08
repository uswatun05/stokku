import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/item_model.dart';
import '../models/activity_log_model.dart';

class StorageService {
  static const String _keyInventory = 'smartstock_inventory';
  static const String _keyLogs = 'smartstock_logs';
  static const String _keyAudioMuted = 'smartstock_audio_muted';

  // Singleton pattern
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  // In-memory cache untuk performa responsif
  List<ItemModel> _inventoryCache = [];
  List<ActivityLogModel> _logsCache = [];
  bool _isInitialized = false;

  List<ItemModel> get inventory => List.unmodifiable(_inventoryCache);
  List<ActivityLogModel> get logs => List.unmodifiable(_logsCache);

  // ==========================================
  // 1. INITIALIZATION & SYNC
  // ==========================================
  Future<void> init() async {
    if (_isInitialized) return;
    await loadInventory();
    await loadLogs();
    _isInitialized = true;
  }

  // ==========================================
  // 2. INVENTORY CRUD OPERATIONS
  // ==========================================

  /// Mengambil seluruh data stok dari SharedPreferences
  /// Jika belum ada di penyimpanan lokal, gunakan default 11 item dari ItemModel.defaultInventory
  Future<List<ItemModel>> loadInventory() async {
    final prefs = await SharedPreferences.getInstance();
    final String? jsonStr = prefs.getString(_keyInventory);

    if (jsonStr != null && jsonStr.isNotEmpty) {
      try {
        final List<dynamic> decoded = jsonDecode(jsonStr);
        _inventoryCache = decoded.map((e) => ItemModel.fromJson(e as Map<String, dynamic>)).toList();
      } catch (e) {
        // Fallback jika format data korup
        _inventoryCache = List.from(ItemModel.defaultInventory);
        await saveInventory(_inventoryCache);
      }
    } else {
      _inventoryCache = List.from(ItemModel.defaultInventory);
      await saveInventory(_inventoryCache);
    }

    return _inventoryCache;
  }

  /// Menyimpan seluruh list inventory ke SharedPreferences
  Future<bool> saveInventory(List<ItemModel> items) async {
    final prefs = await SharedPreferences.getInstance();
    _inventoryCache = List.from(items);
    final String encoded = jsonEncode(_inventoryCache.map((e) => e.toJson()).toList());
    return await prefs.setString(_keyInventory, encoded);
  }

  /// Mencari barang berdasarkan ID (misal: "BRG-001")
  ItemModel? getItemById(String id) {
    try {
      return _inventoryCache.firstWhere((i) => i.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Mencari barang berdasarkan Barcode (misal: "089686010924" atau "CRH-8491")
  ItemModel? getItemByBarcode(String barcode) {
    final cleanBarcode = barcode.trim().toUpperCase();
    try {
      return _inventoryCache.firstWhere(
        (i) => i.barcode.trim().toUpperCase() == cleanBarcode,
      );
    } catch (_) {
      return null;
    }
  }

  /// Menambah barang baru ke dalam stok
  Future<bool> addItem(ItemModel newItem) async {
    // Validasi apakah barcode sudah pernah dipakai barang lain
    if (newItem.barcode.isNotEmpty) {
      final exists = _inventoryCache.any(
        (i) => i.barcode.trim().toUpperCase() == newItem.barcode.trim().toUpperCase(),
      );
      if (exists) return false;
    }

    final updated = List<ItemModel>.from(_inventoryCache)..add(newItem);
    final success = await saveInventory(updated);
    if (success) {
      await addLog(
        'Tambah Barang',
        '${newItem.name} (+${newItem.stock} ${newItem.unit}) didaftarkan ke sistem.',
        type: 'success',
      );
    }
    return success;
  }

  /// Memperbarui informasi barang yang sudah ada
  Future<bool> updateItem(ItemModel updatedItem) async {
    final index = _inventoryCache.indexWhere((i) => i.id == updatedItem.id);
    if (index == -1) return false;

    final updatedList = List<ItemModel>.from(_inventoryCache);
    updatedList[index] = updatedItem;
    final success = await saveInventory(updatedList);
    if (success) {
      await addLog(
        'Update Produk',
        'Data ${updatedItem.name} berhasil diperbarui.',
        type: 'info',
      );
    }
    return success;
  }

  /// Menghapus barang dari daftar stok
  Future<bool> deleteItem(String id) async {
    final item = getItemById(id);
    if (item == null) return false;

    final updatedList = List<ItemModel>.from(_inventoryCache)..removeWhere((i) => i.id == id);
    final success = await saveInventory(updatedList);
    if (success) {
      await addLog(
        'Hapus Barang',
        '${item.name} dihapus permanen dari sistem stok.',
        type: 'danger',
      );
    }
    return success;
  }

  /// Mutasi cepat penambahan/pengurangan kuantitas stok (+/- delta)
  Future<ItemModel?> adjustStockDelta(String id, double delta, {String? customAction}) async {
    final item = getItemById(id);
    if (item == null) return null;

    final double newStock = max(0.0, item.stock + delta);
    final updatedItem = item.copyWith(stock: newStock);
    final success = await updateItemSilently(updatedItem);

    if (success) {
      final sign = delta >= 0 ? '+' : '';
      final action = customAction ?? (delta < 0 ? 'Penjualan' : 'Restock');
      await addLog(
        action,
        '${item.name} (${sign}$delta ${item.unit}) -> Sisa: $newStock ${item.unit}',
        type: delta < 0 ? 'success' : 'info',
      );
      return updatedItem;
    }
    return null;
  }

  /// Update item tanpa memicu log otomatis (internal helper)
  Future<bool> updateItemSilently(ItemModel updatedItem) async {
    final index = _inventoryCache.indexWhere((i) => i.id == updatedItem.id);
    if (index == -1) return false;

    final updatedList = List<ItemModel>.from(_inventoryCache);
    updatedList[index] = updatedItem;
    return await saveInventory(updatedList);
  }

  /// Mereset kembali database stok ke 11 produk awal default
  Future<bool> resetToDefault() async {
    final success = await saveInventory(ItemModel.defaultInventory);
    if (success) {
      await addLog('Reset Database', 'Database inventaris dikembalikan ke data awal pabrik.', type: 'warning');
    }
    return success;
  }

  // ==========================================
  // 3. GENERATOR KODE OTOMATIS
  // ==========================================

  /// Membuat barcode unik acak untuk barang curah: misal "CRH-8492"
  String generateCurahBarcode() {
    final random = Random();
    String code = '';
    bool exists = true;
    int attempts = 0;

    while (exists && attempts < 100) {
      attempts++;
      final num = 1000 + random.nextInt(9000);
      code = 'CRH-$num';
      exists = _inventoryCache.any((i) => i.barcode.trim().toUpperCase() == code);
    }

    return code.isNotEmpty ? code : 'CRH-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}';
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

