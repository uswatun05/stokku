import 'package:flutter/material.dart';

enum ItemStatus {
  overstock,
  menipis,
  aman,
}

class ItemModel {
  final String id;
  final String name;
  final String type; // 'barcode' atau 'computer_vision' / 'curah'
  final String barcode;
  final String category;
  final double stock;
  final double minStock;
  final double maxStock;
  final String unit;
  final String img;
  final String? imageUrl;
  final String? confidence;
  final List<String>? keywords;
  final double price;

  const ItemModel({
    required this.id,
    required this.name,
    required this.type,
    required this.barcode,
    required this.category,
    required this.stock,
    required this.minStock,
    required this.maxStock,
    required this.unit,
    required this.img,
    this.imageUrl,
    this.confidence,
    this.keywords,
    this.price = 5000.0,
  });

  // ==========================================
  // HELPER GETTERS & BUSINESS LOGIC
  // ==========================================

  bool get isCurah => type == 'computer_vision' || type == 'curah';

  ItemStatus get status {
    if (stock >= maxStock) {
      return ItemStatus.overstock;
    } else if (stock <= minStock) {
      return ItemStatus.menipis;
    } else {
      return ItemStatus.aman;
    }
  }

  String get statusLabel {
    switch (status) {
      case ItemStatus.overstock:
        return 'Overstock';
      case ItemStatus.menipis:
        return 'Stok Menipis';
      case ItemStatus.aman:
        return 'Stok Aman';
    }
  }

  Color get statusBgColor {
    switch (status) {
      case ItemStatus.overstock:
        return const Color(0xFFFEE2E2); // red-100
      case ItemStatus.menipis:
        return const Color(0xFFFEF3C7); // amber-100
      case ItemStatus.aman:
        return const Color(0xFFDCFCE7); // emerald-100
    }
  }

  Color get statusTextColor {
    switch (status) {
      case ItemStatus.overstock:
        return const Color(0xFFDC2626); // red-600
      case ItemStatus.menipis:
        return const Color(0xFFD97706); // amber-600
      case ItemStatus.aman:
        return const Color(0xFF16A34A); // emerald-600
    }
  }

  double get capacityPercentage {
    if (maxStock <= 0) return 0.0;
    return (stock / maxStock).clamp(0.0, 1.0);
  }

  int get capacityPercentageInt {
    if (maxStock <= 0) return 0;
    return ((stock / maxStock) * 100).round();
  }

  // ==========================================
  // COPYWITH & JSON SERIALIZATION
  // ==========================================

  ItemModel copyWith({
    String? id,
    String? name,
    String? type,
    String? barcode,
    String? category,
    double? stock,
    double? minStock,
    double? maxStock,
    String? unit,
    String? img,
    String? imageUrl,
    String? confidence,
    List<String>? keywords,
    double? price,
  }) {
    return ItemModel(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      barcode: barcode ?? this.barcode,
      category: category ?? this.category,
      stock: stock ?? this.stock,
      minStock: minStock ?? this.minStock,
      maxStock: maxStock ?? this.maxStock,
      unit: unit ?? this.unit,
      img: img ?? this.img,
      imageUrl: imageUrl ?? this.imageUrl,
      confidence: confidence ?? this.confidence,
      keywords: keywords ?? this.keywords,
      price: price ?? this.price,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'barcode': barcode,
      'category': category,
      'stock': stock,
      'minStock': minStock,
      'maxStock': maxStock,
      'unit': unit,
      'img': img,
      'imageUrl': imageUrl,
      'confidence': confidence,
      'keywords': keywords,
      'price': price,
    };
  }

  factory ItemModel.fromJson(Map<String, dynamic> json) {
    return ItemModel(
      id: json['id'] as String,
      name: json['name'] as String,
      type: json['type'] as String? ?? 'barcode',
      barcode: json['barcode'] as String? ?? '',
      category: json['category'] as String? ?? 'Umum',
      stock: (json['stock'] as num).toDouble(),
      minStock: (json['minStock'] as num).toDouble(),
      maxStock: (json['maxStock'] as num).toDouble(),
      unit: json['unit'] as String? ?? 'pcs',
      img: json['img'] as String? ?? '📦',
      imageUrl: json['imageUrl'] as String?,
      confidence: json['confidence'] as String?,
      keywords: (json['keywords'] as List<dynamic>?)?.map((e) => e.toString()).toList(),
      price: (json['price'] as num?)?.toDouble() ?? 5000.0,
    );
  }

  // ==========================================
  // INITIAL MOCK DATA (11 DEFAULT ITEMS)
  // ==========================================
  static List<ItemModel> defaultInventory = [
    const ItemModel(
      id: "BRG-001",
      name: "Indomie Goreng Spesial 85g",
      type: "barcode",
      barcode: "089686010924",
      category: "Makanan Instan",
      stock: 36.0,
      minStock: 10.0,
      maxStock: 40.0,
      unit: "pcs",
      img: "🍜",
      price: 3500.0,
      imageUrl: "https://images.unsplash.com/photo-1612927601601-6638404737ce?w=400&auto=format&fit=crop&q=80",
    ),
    const ItemModel(
      id: "BRG-002",
      name: "Sabun Mandi Lifebuoy Total 10",
      type: "barcode",
      barcode: "8999999052028",
      category: "Perawatan Tubuh",
      stock: 4.0,
      minStock: 8.0,
      maxStock: 25.0,
      unit: "pcs",
      img: "🧼",
      price: 4500.0,
      imageUrl: "https://images.unsplash.com/photo-1607006314644-88e999999c01?w=400&auto=format&fit=crop&q=80",
    ),
    const ItemModel(
      id: "BRG-003",
      name: "Kopi Kapal Api Spesial Mix",
      type: "barcode",
      barcode: "8991001101234",
      category: "Minuman",
      stock: 16.0,
      minStock: 10.0,
      maxStock: 30.0,
      unit: "sachet",
      img: "☕",
      price: 2000.0,
      imageUrl: "https://images.unsplash.com/photo-1541167760496-1628856ab772?w=400&auto=format&fit=crop&q=80",
    ),
    const ItemModel(
      id: "BRG-004",
      name: "Minyak Goreng Bimoli 1 Liter",
      type: "barcode",
      barcode: "8992745123456",
      category: "Sembako",
      stock: 3.0,
      minStock: 5.0,
      maxStock: 20.0,
      unit: "pouch",
      img: "🛢️",
      price: 19500.0,
      imageUrl: "https://images.unsplash.com/photo-1474979266404-7eaacbcd87c5?w=400&auto=format&fit=crop&q=80",
    ),
    const ItemModel(
      id: "BRG-005",
      name: "Rokok Sampoerna A Mild 16",
      type: "barcode",
      barcode: "8992999123456",
      category: "Rokok",
      stock: 22.0,
      minStock: 5.0,
      maxStock: 20.0,
      unit: "bungkus",
      img: "🚬",
      price: 34000.0,
      imageUrl: "https://images.unsplash.com/photo-1527864550417-7fd91fc51a46?w=400&auto=format&fit=crop&q=80",
    ),
    const ItemModel(
      id: "BRG-006",
      name: "Telur Ayam Negeri Curah",
      type: "computer_vision",
      barcode: "CRH-8491",
      category: "Sembako Curah",
      stock: 14.5,
      minStock: 3.0,
      maxStock: 15.0,
      unit: "kg",
      img: "🥚",
      confidence: "96.4%",
      price: 28000.0,
      keywords: ["telur", "telur ayam", "egg"],
      imageUrl: "https://images.unsplash.com/photo-1582722872445-44dc5f7e3c8f?w=600&auto=format&fit=crop&q=80",
    ),
    const ItemModel(
      id: "BRG-007",
      name: "Beras Ramos Wangi Curah",
      type: "computer_vision",
      barcode: "CRH-8492",
      category: "Sembako Curah",
      stock: 8.0,
      minStock: 10.0,
      maxStock: 50.0,
      unit: "kg",
      img: "🌾",
      confidence: "94.2%",
      price: 14000.0,
      keywords: ["beras", "rice"],
      imageUrl: "https://images.unsplash.com/photo-1586201375761-83865001e31c?w=600&auto=format&fit=crop&q=80",
    ),
    const ItemModel(
      id: "BRG-008",
      name: "Bawang Merah Brebes",
      type: "computer_vision",
      barcode: "CRH-8493",
      category: "Bumbu Dapur",
      stock: 4.5,
      minStock: 2.0,
      maxStock: 10.0,
      unit: "kg",
      img: "🧅",
      confidence: "97.1%",
      price: 32000.0,
      keywords: ["bawang", "bawang merah", "shallot"],
      imageUrl: "https://images.unsplash.com/photo-1618512496248-a07fe83aa8cb?w=600&auto=format&fit=crop&q=80",
    ),
    const ItemModel(
      id: "BRG-009",
      name: "Bawang Putih Kating",
      type: "computer_vision",
      barcode: "CRH-8494",
      category: "Bumbu Dapur",
      stock: 1.2,
      minStock: 2.0,
      maxStock: 10.0,
      unit: "kg",
      img: "🧄",
      confidence: "93.5%",
      price: 38000.0,
      keywords: ["bawang putih", "garlic"],
      imageUrl: "https://images.unsplash.com/photo-1615485500704-8e990f9900f7?w=600&auto=format&fit=crop&q=80",
    ),
    const ItemModel(
      id: "BRG-010",
      name: "Minyak Goreng Curah (Kiloan)",
      type: "computer_vision",
      barcode: "CRH-8495",
      category: "Sembako Curah",
      stock: 18.0,
      minStock: 5.0,
      maxStock: 20.0,
      unit: "liter",
      img: "🛢️",
      confidence: "91.8%",
      price: 16000.0,
      keywords: ["minyak curah", "cooking oil"],
      imageUrl: "https://images.unsplash.com/photo-1474979266404-7eaacbcd87c5?w=600&auto=format&fit=crop&q=80",
    ),
    const ItemModel(
      id: "BRG-011",
      name: "Cabai Rawit Merah Pedas",
      type: "computer_vision",
      barcode: "CRH-8496",
      category: "Bumbu Dapur",
      stock: 0.8,
      minStock: 1.5,
      maxStock: 5.0,
      unit: "kg",
      img: "🌶️",
      confidence: "98.0%",
      price: 45000.0,
      keywords: ["cabai", "cabe", "chili"],
      imageUrl: "https://images.unsplash.com/photo-1588252303782-cb80119abd6d?w=600&auto=format&fit=crop&q=80",
    ),
  ];
}

