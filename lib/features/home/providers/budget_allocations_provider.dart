import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/auth_provider.dart';

// ── Model ─────────────────────────────────────────────────────────────────

class BudgetGroupAllocation {
  final String groupName;
  final double percent; // 0..100

  const BudgetGroupAllocation({
    required this.groupName,
    required this.percent,
  });

  Map<String, dynamic> toMap() => {
        'groupName': groupName,
        'percent': percent,
      };

  factory BudgetGroupAllocation.fromMap(Map<String, dynamic> m) =>
      BudgetGroupAllocation(
        groupName: m['groupName'] ?? '',
        percent: (m['percent'] ?? 0.0).toDouble(),
      );
}

// ── Provider: stream das alocações ───────────────────────────────────────

final budgetAllocationsProvider =
    StreamProvider<List<BudgetGroupAllocation>>((ref) {
  final user = ref.watch(firebaseAuthProvider).currentUser;
  if (user == null) return Stream.value([]);

  final firestore = ref.watch(firestoreProvider);
  return firestore
      .collection('users')
      .doc(user.uid)
      .snapshots()
      .map((doc) {
    if (!doc.exists || doc.data() == null) return [];
    final raw = doc.data()!['budgetAllocations'] as List<dynamic>?;
    if (raw == null) return [];
    return raw
        .map((e) => BudgetGroupAllocation.fromMap(e as Map<String, dynamic>))
        .toList();
  });
});

// ── Notifier: salva alocações ─────────────────────────────────────────────

class BudgetAllocationsNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;
  BudgetAllocationsNotifier(this._ref) : super(const AsyncValue.data(null));

  Future<bool> save(List<BudgetGroupAllocation> allocations) async {
    state = const AsyncValue.loading();
    try {
      final user = _ref.read(firebaseAuthProvider).currentUser!;
      await _ref
          .read(firestoreProvider)
          .collection('users')
          .doc(user.uid)
          .set(
            {'budgetAllocations': allocations.map((a) => a.toMap()).toList()},
            SetOptions(merge: true),
          );
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }
}

final budgetAllocationsNotifierProvider =
    StateNotifierProvider<BudgetAllocationsNotifier, AsyncValue<void>>(
        (ref) => BudgetAllocationsNotifier(ref));