import 'package:cloud_firestore/cloud_firestore.dart';

class ReceiptItem {
  final String name;
  final double quantity;
  final String unit;
  final double unitPrice;
  final double totalPrice;

  const ReceiptItem({
    required this.name,
    required this.quantity,
    required this.unit,
    required this.unitPrice,
    required this.totalPrice,
  });

  Map<String, dynamic> toMap() => {
        'name': name,
        'quantity': quantity,
        'unit': unit,
        'unitPrice': unitPrice,
        'totalPrice': totalPrice,
      };

  factory ReceiptItem.fromMap(Map<String, dynamic> map) {
    return ReceiptItem(
      name: (map['name'] ?? '').toString(),
      quantity: (map['quantity'] is num) ? (map['quantity'] as num).toDouble() : 1.0,
      unit: (map['unit'] ?? 'UN').toString(),
      unitPrice: (map['unitPrice'] is num) ? (map['unitPrice'] as num).toDouble() : 0.0,
      totalPrice: (map['totalPrice'] is num) ? (map['totalPrice'] as num).toDouble() : 0.0,
    );
  }
}

class ReceiptModel {
  final String id;
  final String qrUrl;

  final String storeName;
  final String storeCnpj;
  final String storeAddress;

  final DateTime issuedAt;
  final double total;
  final double totalDiscount;
  final String accessKey;

  final List<ReceiptItem> items;

  const ReceiptModel({
    required this.id,
    required this.qrUrl,
    required this.storeName,
    required this.storeCnpj,
    required this.storeAddress,
    required this.issuedAt,
    required this.total,
    required this.totalDiscount,
    required this.accessKey,
    required this.items,
  });

  Map<String, dynamic> toFirestore() => {
        'id': id,
        'qrUrl': qrUrl,
        'storeName': storeName,
        'storeCnpj': storeCnpj,
        'storeAddress': storeAddress,
        'issuedAt': Timestamp.fromDate(issuedAt),
        'total': total,
        'totalDiscount': totalDiscount,
        'accessKey': accessKey,
        'items': items.map((e) => e.toMap()).toList(),
      };

  factory ReceiptModel.fromFirestore(
    Map<String, dynamic> data, {
    String id = '',
  }) {
    final issuedRaw = data['issuedAt'];
    DateTime issued;
    if (issuedRaw is Timestamp) {
      issued = issuedRaw.toDate();
    } else if (issuedRaw is DateTime) {
      issued = issuedRaw;
    } else {
      issued = DateTime.now();
    }

    final itemsRaw = (data['items'] as List?) ?? const [];
    final parsedItems = itemsRaw
        .whereType<Map>()
        .map((m) => ReceiptItem.fromMap(Map<String, dynamic>.from(m)))
        .toList();

    return ReceiptModel(
      id: id.isNotEmpty ? id : (data['id'] ?? '').toString(),
      qrUrl: (data['qrUrl'] ?? '').toString(),
      storeName: (data['storeName'] ?? '').toString(),
      storeCnpj: (data['storeCnpj'] ?? '').toString(),
      storeAddress: (data['storeAddress'] ?? '').toString(),
      issuedAt: issued,
      total: (data['total'] is num) ? (data['total'] as num).toDouble() : 0.0,
      totalDiscount: (data['totalDiscount'] is num)
          ? (data['totalDiscount'] as num).toDouble()
          : 0.0,
      accessKey: (data['accessKey'] ?? '').toString(),
      items: parsedItems,
    );
  }
}
