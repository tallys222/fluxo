import 'package:cloud_firestore/cloud_firestore.dart';

class UserProfile {
  final String uid;
  final String name;
  final String email;
  final double monthlyBudget;
  final String currency;
  final DateTime createdAt;

  const UserProfile({
    required this.uid,
    required this.name,
    required this.email,
    required this.monthlyBudget,
    required this.currency,
    required this.createdAt,
  });

  factory UserProfile.fromFirestore(String uid, Map<String, dynamic> data) {
    return UserProfile(
      uid: uid,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      monthlyBudget: (data['monthlyBudget'] ?? 0.0).toDouble(),
      currency: data['currency'] ?? 'BRL',
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'name': name,
        'email': email,
        'monthlyBudget': monthlyBudget,
        'currency': currency,
      };

  UserProfile copyWith({
    String? name,
    double? monthlyBudget,
  }) =>
      UserProfile(
        uid: uid,
        name: name ?? this.name,
        email: email,
        monthlyBudget: monthlyBudget ?? this.monthlyBudget,
        currency: currency,
        createdAt: createdAt,
      );
}