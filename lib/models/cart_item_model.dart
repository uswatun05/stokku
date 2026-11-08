import 'item_model.dart';

class CartItemModel {
  final ItemModel item;
  double qty;

  CartItemModel({
    required this.item,
    required this.qty,
  });

  double get subtotal => item.price * qty;

  Map<String, dynamic> toJson() {
    return {
      'item': item.toJson(),
      'qty': qty,
    };
  }

  factory CartItemModel.fromJson(Map<String, dynamic> json) {
    return CartItemModel(
      item: ItemModel.fromJson(json['item'] as Map<String, dynamic>),
      qty: (json['qty'] as num).toDouble(),
    );
  }
}

