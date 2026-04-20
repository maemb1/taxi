import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rxdart/rxdart.dart';
import 'package:taxi_app/shared/models/app_user.dart';

final firebaseAuthProvider =
    Provider<FirebaseAuth>((ref) => FirebaseAuth.instance);

final firestoreProvider =
    Provider<FirebaseFirestore>((ref) => FirebaseFirestore.instance);

// Stream del usuario autenticado con su perfil de Firestore en tiempo real
final authStateProvider = StreamProvider<AppUser?>((ref) {
  final auth = ref.watch(firebaseAuthProvider);
  final firestore = ref.watch(firestoreProvider);

  return auth.authStateChanges().switchMap((firebaseUser) {
    if (firebaseUser == null) return Stream.value(null);
    return firestore
        .collection('users')
        .doc(firebaseUser.uid)
        .snapshots()
        .map((doc) => doc.exists ? AppUser.fromFirestore(doc) : null);
  });
});

// Usuario actual (síncrono, para usar dentro de providers)
final currentUserProvider = Provider<AppUser?>((ref) {
  return ref.watch(authStateProvider).valueOrNull;
});
