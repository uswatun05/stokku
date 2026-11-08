import 'package:flutter_test/flutter_test.dart';
import 'package:smartstock_ai/models/item_model.dart';

void main() {
  test('ItemModel default inventory test', () {
    final list = ItemModel.defaultInventory;
    expect(list.isNotEmpty, true);
  });
}
