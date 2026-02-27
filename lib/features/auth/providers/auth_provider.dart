import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Firebase Auth instance
final firebaseAuthProvider = Provider<FirebaseAuth>((ref) => FirebaseAuth.instance);
final firestoreProvider = Provider<FirebaseFirestore>((ref) => FirebaseFirestore.instance);

// Auth state stream
final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(firebaseAuthProvider).authStateChanges();
});

// Auth notifier
class AuthNotifier extends StateNotifier<AsyncValue<void>> {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  AuthNotifier(this._auth, this._firestore) : super(const AsyncValue.data(null));

  Future<void> signIn(String email, String password) async {
    state = const AsyncValue.loading();
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      state = const AsyncValue.data(null);
    } on FirebaseAuthException catch (e) {
      state = AsyncValue.error(_mapFirebaseError(e.code), StackTrace.current);
    }
  }

  Future<void> signUp(String name, String email, String password) async {
    state = const AsyncValue.loading();
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      await cred.user!.updateDisplayName(name);

      // Create user document in Firestore
      await _firestore.collection('users').doc(cred.user!.uid).set({
        'name': name,
        'email': email,
        'createdAt': FieldValue.serverTimestamp(),
        'currency': 'BRL',
        'monthlyBudget': 0.0,
      });

      state = const AsyncValue.data(null);
    } on FirebaseAuthException catch (e) {
      state = AsyncValue.error(_mapFirebaseError(e.code), StackTrace.current);
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
    state = const AsyncValue.data(null);
  }

  Future<void> resetPassword(String email) async {
    state = const AsyncValue.loading();
    try {
      await _auth.sendPasswordResetEmail(email: email);
      state = const AsyncValue.data(null);
    } on FirebaseAuthException catch (e) {
      state = AsyncValue.error(_mapFirebaseError(e.code), StackTrace.current);
    }
  }

  String _mapFirebaseError(String code) {
    switch (code) {
      case 'user-not-found':
        return 'Usuário não encontrado.';
      case 'wrong-password':
        return 'Senha incorreta.';
      case 'email-already-in-use':
        return 'Este e-mail já está em uso.';
      case 'weak-password':
        return 'Senha muito fraca. Use ao menos 6 caracteres.';
      case 'invalid-email':
        return 'E-mail inválido.';
      case 'too-many-requests':
        return 'Muitas tentativas. Tente novamente mais tarde.';
      default:
        return 'Ocorreu um erro. Tente novamente.';
    }
  }
}

final authNotifierProvider = StateNotifierProvider<AuthNotifier, AsyncValue<void>>((ref) {
  return AuthNotifier(
    ref.watch(firebaseAuthProvider),
    ref.watch(firestoreProvider),
  );
});