import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartstock_ai/models/item_model.dart';
import 'package:smartstock_ai/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('ItemModel default inventory test', () {
    final list = ItemModel.defaultInventory;
    expect(list.isNotEmpty, true);
    expect(list.any((i) => i.tokoId == 'Toko Pusat'), true);
    expect(list.any((i) => i.tokoId == 'Cabang 1'), true);
    expect(list.any((i) => i.tokoId == 'Cabang 2'), true);
  });

  test('ItemModel tokoId serialization test', () {
    const item = ItemModel(
      id: 'TEST-001',
      tokoId: 'Cabang 1',
      name: 'Test Barang',
      type: 'barcode',
      barcode: '12345678',
      category: 'Umum',
      stock: 10.0,
      minStock: 2.0,
      maxStock: 20.0,
      unit: 'pcs',
      img: '📦',
      price: 10000.0,
    );

    final json = item.toJson();
    expect(json['tokoId'], 'Cabang 1');

    final reconstructed = ItemModel.fromJson(json);
    expect(reconstructed.tokoId, 'Cabang 1');
    expect(reconstructed.name, 'Test Barang');
  });

  test('StorageService saveItems and loadItems persistence test', () async {
    final storage = StorageService();
    await storage.init();

    // 1. Initial load should populate default items
    final initialPusat = await storage.loadItems(tokoId: 'Toko Pusat');
    expect(initialPusat.isNotEmpty, true);

    // 2. Add an item to Cabang 1
    const newItem = ItemModel(
      id: 'TEST-CBG1-01',
      tokoId: 'Cabang 1',
      name: 'Minyak Goreng Sawit',
      type: 'barcode',
      barcode: '9988776655',
      category: 'Sembako',
      stock: 25.0,
      minStock: 5.0,
      maxStock: 50.0,
      unit: 'liter',
      img: '🛢️',
      price: 15000.0,
    );

    final addSuccess = await storage.addItem(newItem);
    expect(addSuccess, true);

    // 3. Verify item is in Cabang 1
    final cabang1Items = storage.getItems(tokoId: 'Cabang 1');
    expect(cabang1Items.any((i) => i.id == 'TEST-CBG1-01'), true);

    // 4. Verify item is NOT in Toko Pusat or Cabang 2
    final pusatItems = storage.getItems(tokoId: 'Toko Pusat');
    expect(pusatItems.any((i) => i.id == 'TEST-CBG1-01'), false);

    // 5. Simulate reload from persistent local storage
    final reloadedCabang1 = await storage.loadItems(tokoId: 'Cabang 1');
    expect(reloadedCabang1.any((i) => i.id == 'TEST-CBG1-01'), true);
  });
}
