import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taxi_app/features/auth/data/auth_provider.dart';

class AuthService {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  AuthService(this._auth, this._firestore);

  Future<void> signIn(String email, String password) async {
    await _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  Future<void> updateFcmToken(String uid, String token) async {
    await _firestore.collection('users').doc(uid).update({'fcmToken': token});
  }

  Future<String> createUser({
    required String name,
    required String email,
    required String password,
    required String role,
    String? vehiclePlate,
  }) async {
    FirebaseApp? secondaryApp;
    try {
      secondaryApp = Firebase.app('secondary');
    } catch (_) {}
    secondaryApp ??= await Firebase.initializeApp(
      name: 'secondary',
      options: Firebase.app().options,
    );

    late UserCredential credential;
    try {
      credential = await FirebaseAuth.instanceFor(app: secondaryApp)
          .createUserWithEmailAndPassword(email: email, password: password);
    } finally {
      await FirebaseAuth.instanceFor(app: secondaryApp).signOut();
    }

    final plate = vehiclePlate?.trim().toUpperCase();
    final uid = credential.user!.uid;
    await _firestore.collection('users').doc(uid).set({
      'name': name.trim(),
      'email': email.trim(),
      'role': role,
      if (plate != null && plate.isNotEmpty) 'vehiclePlate': plate,
      'status': 'offline',
      'isActive': true,
    });
    return uid;
  }
}

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(
    ref.watch(firebaseAuthProvider),
    ref.watch(firestoreProvider),
  );
});
