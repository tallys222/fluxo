import 'package:cloud_firestore/cloud_firestore.dart';

enum TransactionType { income, expense }

class TransactionModel {
  final String id;
  final String title;
  final double amount;
  final TransactionType type;
  final String categoryId;
  final String categoryName;
  final String categoryIcon;
  final String categoryColor;
  final DateTime date;
  final String? note;
  final String? receiptId; // linked NF-e if scanned

  const TransactionModel({
    required this.id,
    required this.title,
    required this.amount,
    required this.type,
    required this.categoryId,
    required this.categoryName,
    required this.categoryIcon,
    required this.categoryColor,
    required this.date,
    this.note,
    this.receiptId,
  });

  factory TransactionModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return TransactionModel(
      id: doc.id,
      title: data['title'] ?? '',
      amount: (data['amount'] ?? 0.0).toDouble(),
      type: data['type'] == 'income' ? TransactionType.income : TransactionType.expense,
      categoryId: data['categoryId'] ?? '',
      categoryName: data['categoryName'] ?? 'Outros',
      categoryIcon: data['categoryIcon'] ?? '📦',
      categoryColor: data['categoryColor'] ?? '#6B7A8D',
      date: (data['date'] as Timestamp).toDate(),
      note: data['note'],
      receiptId: data['receiptId'],
    );
  }

  Map<String, dynamic> toFirestore() => {
        'title': title,
        'amount': amount,
        'type': type == TransactionType.income ? 'income' : 'expense',
        'categoryId': categoryId,
        'categoryName': categoryName,
        'categoryIcon': categoryIcon,
        'categoryColor': categoryColor,
        'date': Timestamp.fromDate(date),
        'note': note,
        'receiptId': receiptId,
        'createdAt': FieldValue.serverTimestamp(),
      };
}

class CategoryModel {
  final String id;
  final String name;
  final String icon;
  final String color;
  final TransactionType type;
  final bool isDefault;

  const CategoryModel({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    required this.type,
    this.isDefault = false,
  });

  factory CategoryModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CategoryModel(
      id: doc.id,
      name: data['name'] ?? '',
      icon: data['icon'] ?? '📦',
      color: data['color'] ?? '#6B7A8D',
      type: data['type'] == 'income' ? TransactionType.income : TransactionType.expense,
      isDefault: data['isDefault'] ?? false,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'name': name,
        'icon': icon,
        'color': color,
        'type': type == TransactionType.income ? 'income' : 'expense',
        'isDefault': isDefault,
      };
}

// Default categories seeded on first login
const List<Map<String, dynamic>> kDefaultCategories = [
  // Expenses
  {'name': 'Alimentação', 'icon': '🛒', 'color': '#FF9800', 'type': 'expense'},
  {'name': 'Moradia', 'icon': '🏠', 'color': '#2196F3', 'type': 'expense'},
  {'name': 'Transporte', 'icon': '🚗', 'color': '#9C27B0', 'type': 'expense'},
  {'name': 'Saúde', 'icon': '❤️', 'color': '#F44336', 'type': 'expense'},
  {'name': 'Educação', 'icon': '📚', 'color': '#3F51B5', 'type': 'expense'},
  {'name': 'Lazer', 'icon': '🎮', 'color': '#00BCD4', 'type': 'expense'},
  {'name': 'Vestuário', 'icon': '👗', 'color': '#E91E63', 'type': 'expense'},
  {'name': 'Assinaturas', 'icon': '📱', 'color': '#607D8B', 'type': 'expense'},
  {'name': 'Outros', 'icon': '📦', 'color': '#9E9E9E', 'type': 'expense'},
  // Income
  {'name': 'Salário', 'icon': '💼', 'color': '#00C896', 'type': 'income'},
  {'name': 'Freelance', 'icon': '💻', 'color': '#4CAF50', 'type': 'income'},
  {'name': 'Investimentos', 'icon': '📈', 'color': '#8BC34A', 'type': 'income'},
  {'name': 'Outros', 'icon': '💰', 'color': '#CDDC39', 'type': 'income'},
];