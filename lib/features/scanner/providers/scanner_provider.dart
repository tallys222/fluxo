import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../auth/providers/auth_provider.dart';
import '../../home/providers/dashboard_provider.dart';
import '../../transactions/models/transaction_model.dart';
import '../../transactions/repositories/transaction_repository.dart';
import '../models/receipt_model.dart';
import '../services/sefaz_service.dart';

// ── Scan state ────────────────────────────────────────────────────────────

enum ScanStatus { idle, loading, success, error }

class ScanState {
  final ScanStatus status;
  final ReceiptModel? receipt;
  final String? errorMessage;

  const ScanState({
    this.status = ScanStatus.idle,
    this.receipt,
    this.errorMessage,
  });

  ScanState copyWith({
    ScanStatus? status,
    ReceiptModel? receipt,
    String? errorMessage,
  }) =>
      ScanState(
        status: status ?? this.status,
        receipt: receipt ?? this.receipt,
        errorMessage: errorMessage ?? this.errorMessage,
      );
}

// ── Scanner notifier ──────────────────────────────────────────────────────

class ScannerNotifier extends StateNotifier<ScanState> {
  final SefazService _sefaz;
  final FirebaseFirestore _firestore;
  final TransactionRepository _txRepo;
  final Ref _ref;
  final String _uid;

  final _processedUrls = <String>{};

  ScannerNotifier(this._sefaz, this._firestore, this._txRepo, this._ref, this._uid)
      : super(const ScanState());

  Future<void> processQrCode(String url) async {
    // Debounce: ignore already processed URLs
    if (_processedUrls.contains(url)) return;
    if (state.status == ScanStatus.loading) return;

    _processedUrls.add(url);
    state = state.copyWith(status: ScanStatus.loading);

    try {
      // Check if this receipt was already imported (by QR URL)
      final existing = await _firestore
          .collection('users')
          .doc(_uid)
          .collection('receipts')
          .where('qrUrl', isEqualTo: url)
          .limit(1)
          .get();

      if (existing.docs.isNotEmpty) {
        state = state.copyWith(
          status: ScanStatus.error,
          errorMessage: 'Esta nota fiscal já foi importada anteriormente.',
        );
        return;
      }

      final receipt = await _sefaz.fetchReceipt(url);
      state = state.copyWith(status: ScanStatus.success, receipt: receipt);
    } catch (e) {
      state = state.copyWith(
        status: ScanStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  /// Consulta NF-e pela chave de acesso (44 dígitos, sem espaços)
  /// para casos em que o QR Code da nota está com URL inválida.
  Future<void> processAccessKey(String rawKey) async {
    // Remove spaces, dots, dashes
    final key = rawKey.replaceAll(RegExp(r'[\s\-\.]+'), '');
    if (key.length != 44) {
      state = state.copyWith(
        status: ScanStatus.error,
        errorMessage: 'Chave de acesso inválida. Deve ter 44 dígitos.',
      );
      return;
    }

    // Monta URL de consulta por chave — SEFAZ AL
    // Formato: ?p=CHAVE|cAmb|tpEmis|cDest|hashQRCode
    // Sem o hash, usamos o endpoint de consulta por chave diretamente
    final stateCode = key.substring(0, 2);
    final url = _buildUrlFromKey(stateCode, key);

    if (url == null) {
      state = state.copyWith(
        status: ScanStatus.error,
        errorMessage: 'Estado ${stateCode} ainda não suportado para consulta por chave.',
      );
      return;
    }

    await processQrCode(url);
  }

  String? _buildUrlFromKey(String uf, String key) {
    return switch (uf) {
      '27' => 'https://nfce.sefaz.al.gov.br/nfce/consulta?p=$key|2|1|1|',
      '35' => 'https://www.nfce.fazenda.sp.gov.br/consulta?p=$key|2|1|1|',
      '33' => 'https://nfce.fazenda.rj.gov.br/consulta?p=$key|2|1|1|',
      '31' => 'https://nfce.fazenda.mg.gov.br/consulta?p=$key|2|1|1|',
      '29' => 'https://nfe.sefaz.ba.gov.br/servicos/nfce/consulta.aspx?p=$key|2|1|1|',
      '26' => 'https://nfce.sefaz.pe.gov.br/nfce/consulta?p=$key|2|1|1|',
      '23' => 'https://nfce.sefaz.ce.gov.br/pages/showNFCe.html?p=$key|2|1|1|',
      '41' => 'https://www.fazenda.pr.gov.br/nfce/consulta?p=$key|2|1|1|',
      '43' => 'https://www.sefaz.rs.gov.br/NFCE/NFCE-COM.aspx?p=$key|2|1|1|',
      '42' => 'https://www.sef.sc.gov.br/nfce/consulta?p=$key|2|1|1|',
      '52' => 'https://www.sefaz.go.gov.br/nfce/consulta?p=$key|2|1|1|',
      '53' => 'https://www.fazenda.df.gov.br/nfce/consulta?p=$key|2|1|1|',
      _ => null,
    };
  }

  /// Usado pelo WebView após o usuário resolver o reCAPTCHA manualmente
  void setReceiptFromWebView(dynamic receipt) {
    state = state.copyWith(status: ScanStatus.success, receipt: receipt);
  }

  Future<bool> importReceipt({
    required ReceiptModel receipt,
    required String categoryId,
    required String categoryName,
    required String categoryIcon,
    required String categoryColor,
    int installments = 1,
  }) async {
    try {
      final receiptId = const Uuid().v4();

      // 1. Save receipt document
      await _firestore
          .collection('users')
          .doc(_uid)
          .collection('receipts')
          .doc(receiptId)
          .set(receipt.toFirestore());

      // 2. Create transaction(s)
      final noteText =
          '${receipt.items.length} itens · NF-e ${receipt.accessKey.isNotEmpty ? receipt.accessKey.substring(0, 8) + '...' : ''}';

      if (installments > 1) {
        // Parcelado: cria N transações sem receiptId (salvo só na 1ª)
        final groupId = DateTime.now().millisecondsSinceEpoch.toString();
        final parcelAmount = double.parse(
          (receipt.total / installments).toStringAsFixed(2),
        );

        for (int i = 0; i < installments; i++) {
          final parcelDate = DateTime(
            receipt.issuedAt.year,
            receipt.issuedAt.month + i,
            receipt.issuedAt.day,
          );
          final transaction = TransactionModel(
            id: '',
            title: '${receipt.storeName} (${i + 1}/$installments)',
            amount: parcelAmount,
            type: TransactionType.expense,
            categoryId: categoryId,
            categoryName: categoryName,
            categoryIcon: categoryIcon,
            categoryColor: categoryColor,
            date: parcelDate,
            note: noteText,
            receiptId: i == 0 ? receiptId : null, // NF-e vinculada só na 1ª parcela
            installmentGroupId: groupId,
            installmentCurrent: i + 1,
            installmentTotal: installments,
          );
          await _txRepo.addTransaction(transaction);
        }
      } else {
        // À vista: única transação
        final transaction = TransactionModel(
          id: '',
          title: receipt.storeName,
          amount: receipt.total,
          type: TransactionType.expense,
          categoryId: categoryId,
          categoryName: categoryName,
          categoryIcon: categoryIcon,
          categoryColor: categoryColor,
          date: receipt.issuedAt,
          note: noteText,
          receiptId: receiptId,
        );
        await _txRepo.addTransaction(transaction);
      }

      // 3. Invalidate dashboard
      _ref.invalidate(dashboardProvider);

      reset();
      return true;
    } catch (_) {
      return false;
    }
  }

  void reset() {
    _processedUrls.clear();
    state = const ScanState();
  }

  void clearError() {
    _processedUrls.clear();
    state = const ScanState();
  }
}

final scannerProvider =
    StateNotifierProvider.autoDispose<ScannerNotifier, ScanState>((ref) {
  return ScannerNotifier(
    ref.watch(sefazServiceProvider),
    ref.watch(firestoreProvider),
    ref.watch(transactionRepositoryProvider),
    ref,
    ref.watch(firebaseAuthProvider).currentUser!.uid,
  );
});