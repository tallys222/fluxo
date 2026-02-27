import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/user_profile_model.dart';

// ── Theme provider ────────────────────────────────────────────────────────

final themeModeProvider =
    StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier();
});

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier() : super(ThemeMode.system) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('themeMode') ?? 'system';
    state = switch (saved) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  Future<void> setTheme(ThemeMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('themeMode', switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      _ => 'system',
    });
  }
}

// ── User profile provider ─────────────────────────────────────────────────

final userProfileProvider =
    StreamProvider<UserProfile?>((ref) {
  final user = ref.watch(firebaseAuthProvider).currentUser;
  if (user == null) return Stream.value(null);

  final firestore = ref.watch(firestoreProvider);
  return firestore
      .collection('users')
      .doc(user.uid)
      .snapshots()
      .map((doc) {
    if (!doc.exists || doc.data() == null) return null;
    return UserProfile.fromFirestore(user.uid, doc.data()!);
  });
});

// ── Profile notifier ──────────────────────────────────────────────────────

class ProfileNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;
  ProfileNotifier(this._ref) : super(const AsyncValue.data(null));

  Future<bool> updateName(String name) async {
    state = const AsyncValue.loading();
    try {
      final user = _ref.read(firebaseAuthProvider).currentUser!;
      // Só atualiza Firestore — updateDisplayName exige re-auth recente
      await _ref
          .read(firestoreProvider)
          .collection('users')
          .doc(user.uid)
          .set({'name': name}, SetOptions(merge: true));
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> updateBudget(double budget) async {
    state = const AsyncValue.loading();
    try {
      final user = _ref.read(firebaseAuthProvider).currentUser!;
      await _ref
          .read(firestoreProvider)
          .collection('users')
          .doc(user.uid)
          .set({'monthlyBudget': budget}, SetOptions(merge: true));
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<void> signOut() async {
    await _ref.read(authNotifierProvider.notifier).signOut();
  }
}

final profileNotifierProvider =
    StateNotifierProvider<ProfileNotifier, AsyncValue<void>>(
        (ref) => ProfileNotifier(ref));

// ── Profile stats ─────────────────────────────────────────────────────────

class ProfileStats {
  final int transactionCount;
  final int receiptCount;
  final int monthsActive;

  const ProfileStats({
    required this.transactionCount,
    required this.receiptCount,
    required this.monthsActive,
  });
}

final profileStatsProvider =
    FutureProvider.autoDispose<ProfileStats>((ref) async {
  final user = ref.watch(firebaseAuthProvider).currentUser;
  if (user == null) {
    return const ProfileStats(
        transactionCount: 0, receiptCount: 0, monthsActive: 0);
  }

  final firestore = ref.watch(firestoreProvider);
  final base = firestore.collection('users').doc(user.uid);

  final results = await Future.wait([
    base.collection('transactions').count().get(),
    base.collection('receipts').count().get(),
  ]);

  final profile = await ref.watch(userProfileProvider.future);
  final days = profile != null
      ? DateTime.now().difference(profile.createdAt).inDays
      : 0;
  final months = (days / 30).ceil();

  return ProfileStats(
    transactionCount: results[0].count ?? 0,
    receiptCount: results[1].count ?? 0,
    monthsActive: months < 1 ? 1 : months,
  );
});