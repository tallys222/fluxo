import 'dart:convert';
import 'dart:io';
import 'package:cloud_functions/cloud_functions.dart';

// ── Modelo de transação extraída ──────────────────────────────────────────

class BillTransaction {
  final String date;
  final String description;
  final double amount;
  final bool isCredit;
  final String? installmentInfo;
  final String? cardLast4;
  final String categoryId;
  final String categoryName;
  final String categoryIcon;
  final String categoryColor;

  BillTransaction({
    required this.date,
    required this.description,
    required this.amount,
    required this.isCredit,
    this.installmentInfo,
    this.cardLast4,
    this.categoryId = 'outros',
    this.categoryName = 'Outros',
    this.categoryIcon = '💳',
    this.categoryColor = '#9E9E9E',
  });

  factory BillTransaction.fromJson(Map<String, dynamic> j) => BillTransaction(
        date: (j['date'] ?? '') as String,
        description: (j['description'] ?? '') as String,
        amount: (j['amount'] as num?)?.toDouble() ?? 0.0,
        isCredit: (j['isCredit'] ?? false) as bool,
        installmentInfo: j['installmentInfo'] as String?,
        cardLast4: j['cardLast4'] as String?,
        categoryId: (j['categoryId'] as String?) ?? 'outros',
        categoryName: (j['categoryName'] as String?) ?? 'Outros',
        categoryIcon: (j['categoryIcon'] as String?) ?? '💳',
        categoryColor: (j['categoryColor'] as String?) ?? '#9E9E9E',
      );

  // Converte "DD/MM" para DateTime
  DateTime toDateTime() {
    try {
      final parts = date.split('/');
      final day = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      final now = DateTime.now();
      // Se o mês for maior que o atual, é do ano passado
      final year = month > now.month ? now.year - 1 : now.year;
      return DateTime(year, month, day);
    } catch (_) {
      return DateTime.now();
    }
  }

  String get displayDate {
    final dt = toDateTime();
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }

  BillTransaction copyWith({
    String? date,
    String? description,
    double? amount,
    bool? isCredit,
    String? installmentInfo,
    String? cardLast4,
    String? categoryId,
    String? categoryName,
    String? categoryIcon,
    String? categoryColor,
  }) =>
      BillTransaction(
        date: date ?? this.date,
        description: description ?? this.description,
        amount: amount ?? this.amount,
        isCredit: isCredit ?? this.isCredit,
        installmentInfo: installmentInfo ?? this.installmentInfo,
        cardLast4: cardLast4 ?? this.cardLast4,
        categoryId: categoryId ?? this.categoryId,
        categoryName: categoryName ?? this.categoryName,
        categoryIcon: categoryIcon ?? this.categoryIcon,
        categoryColor: categoryColor ?? this.categoryColor,
      );
}

// ── Resultado do parsing ──────────────────────────────────────────────────

class BillParseResult {
  final String? issuer;
  final String? cardHolder;
  final String? dueDate;
  final double totalAmount;
  final List<BillTransaction> transactions;

  BillParseResult({
    this.issuer,
    this.cardHolder,
    this.dueDate,
    required this.totalAmount,
    required this.transactions,
  });

  List<BillTransaction> get debits =>
      transactions.where((t) => !t.isCredit).toList();

  List<BillTransaction> get credits =>
      transactions.where((t) => t.isCredit).toList();
}

// ── Serviço ───────────────────────────────────────────────────────────────

class BillParserService {
  static final _functions = FirebaseFunctions.instanceFor(
    region: 'southamerica-east1',
  );

  Future<BillParseResult> parsePdf(File pdfFile) async {
    final bytes = await pdfFile.readAsBytes();
    final base64Pdf = base64Encode(bytes);

    try {
      final callable = _functions.httpsCallable(
        'parseBill',
        options: HttpsCallableOptions(
          timeout: const Duration(seconds: 120),
        ),
      );

      final result = await callable.call({'pdfBase64': base64Pdf});

      final raw = Map<String, dynamic>.from(result.data['data'] as Map);

      final transactions = (raw['transactions'] as List? ?? [])
          .map((t) => BillTransaction.fromJson(Map<String, dynamic>.from(t as Map)))
          .toList();

      return BillParseResult(
        issuer: raw['issuer'] as String?,
        cardHolder: raw['cardHolder'] as String?,
        dueDate: raw['dueDate'] as String?,
        totalAmount: (raw['totalAmount'] as num?)?.toDouble() ?? 0.0,
        transactions: transactions,
      );
    } on FirebaseFunctionsException catch (e) {
      switch (e.code) {
        case 'unauthenticated':
          throw Exception('Faça login para usar esta funcionalidade.');
        case 'invalid-argument':
          throw Exception(e.message ?? 'PDF inválido.');
        case 'resource-exhausted':
          throw Exception(e.message ?? 'Limite diário atingido.');
        default:
          throw Exception('Erro: ${e.message ?? e.code}');
      }
    }
  }
}