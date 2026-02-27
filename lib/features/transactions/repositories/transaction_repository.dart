import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/transaction_model.dart';

class TransactionRepository {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  TransactionRepository(this._firestore, this._auth);

  String get _uid => _auth.currentUser!.uid;

  CollectionReference get _transactionsRef =>
      _firestore.collection('users').doc(_uid).collection('transactions');

  CollectionReference get _categoriesRef =>
      _firestore.collection('users').doc(_uid).collection('categories');

  // ── Transactions ────────────────────────────────────────────────────────

  Future<void> addTransaction(TransactionModel t) async {
    await _transactionsRef.add(t.toFirestore());
  }

  Future<void> updateTransaction(TransactionModel t) async {
    await _transactionsRef.doc(t.id).update(t.toFirestore());
  }

  Future<void> deleteTransaction(String id) async {
    await _transactionsRef.doc(id).delete();
  }

  Stream<List<TransactionModel>> watchTransactionsByMonth(DateTime month) {
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 0, 23, 59, 59);

    return _transactionsRef
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(end))
        .orderBy('date', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => TransactionModel.fromFirestore(d)).toList());
  }

  // ── Categories ────────────────────────────────────────────────────────

  Stream<List<CategoryModel>> watchCategories() {
    return _categoriesRef
        .orderBy('name')
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => CategoryModel.fromFirestore(d)).toList());
  }

  Future<List<CategoryModel>> getCategories() async {
    final snap = await _categoriesRef.orderBy('name').get();
    return snap.docs.map((d) => CategoryModel.fromFirestore(d)).toList();
  }

  Future<void> addCategory(CategoryModel c) async {
    await _categoriesRef.add(c.toFirestore());
  }
}

final transactionRepositoryProvider = Provider<TransactionRepository>((ref) {
  return TransactionRepository(
    ref.watch(firestoreProvider),
    ref.watch(firebaseAuthProvider),
  );
});