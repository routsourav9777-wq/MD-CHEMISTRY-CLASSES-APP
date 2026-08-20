import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  final FirebaseAuth auth = FirebaseAuth.instance;
  final FirebaseFirestore db = FirebaseFirestore.instance;

  // ============================================================
  // LOGIN
  // ============================================================

  Future<UserCredential> login(
    String email,
    String password,
  ) async {
    final credential = await auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    debugPrint(
      '================ FIREBASE LOGIN ================',
    );

    debugPrint(
      'UID: ${credential.user?.uid}',
    );

    debugPrint(
      'EMAIL: ${credential.user?.email}',
    );

    debugPrint(
      '=================================================',
    );

    return credential;
  }

  // ============================================================
  // GET PROFILE
  // ============================================================

  Future<Map<String, dynamic>?> profile() async {
    final user = auth.currentUser;

    if (user == null) {
      debugPrint(
        '❌ currentUser is NULL',
      );

      return null;
    }

    debugPrint(
      '================ PROFILE CHECK ================',
    );

    debugPrint(
      'Firebase UID: ${user.uid}',
    );

    debugPrint(
      'Firebase Email: ${user.email}',
    );

    debugPrint(
      'Firestore path: users/${user.uid}',
    );

    try {
      // --------------------------------------------------------
      // FIRST: SEARCH BY UID
      // --------------------------------------------------------

      final doc = await db.collection('users').doc(user.uid).get();

      debugPrint(
        'Document exists: ${doc.exists}',
      );

      debugPrint(
        'Document ID: ${doc.id}',
      );

      debugPrint(
        'Document data: ${doc.data()}',
      );

      if (doc.exists && doc.data() != null) {
        debugPrint(
          '✅ PROFILE FOUND BY UID',
        );

        return doc.data();
      }

      // --------------------------------------------------------
      // SECOND: SEARCH BY EMAIL
      // --------------------------------------------------------

      if (user.email != null) {
        debugPrint(
          'UID profile not found. '
          'Searching by email...',
        );

        final query = await db
            .collection('users')
            .where(
              'email',
              isEqualTo: user.email!.trim(),
            )
            .limit(1)
            .get();

        debugPrint(
          'Email search documents: '
          '${query.docs.length}',
        );

        if (query.docs.isNotEmpty) {
          debugPrint(
            '✅ PROFILE FOUND BY EMAIL',
          );

          debugPrint(
            'Found document ID: '
            '${query.docs.first.id}',
          );

          debugPrint(
            'Found data: '
            '${query.docs.first.data()}',
          );

          return query.docs.first.data();
        }
      }

      debugPrint(
        '❌ PROFILE NOT FOUND',
      );

      return null;
    } on FirebaseException catch (e) {
      debugPrint(
        '🔥 FIRESTORE ERROR',
      );

      debugPrint(
        'Code: ${e.code}',
      );

      debugPrint(
        'Message: ${e.message}',
      );

      throw Exception(
        'Firestore error: '
        '${e.code} - ${e.message}',
      );
    }
  }

  // ============================================================
  // REGISTER STUDENT
  // ============================================================

  Future<void> registerStudent({
    required String name,
    required String email,
    required String phone,
    required String semester,
    required String password,
  }) async {
    // ----------------------------------------------------------
    // CREATE FIREBASE ACCOUNT
    // ----------------------------------------------------------

    final cred = await auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    final user = cred.user;

    if (user == null) {
      throw Exception(
        'Unable to create user.',
      );
    }

    // ----------------------------------------------------------
    // SAVE STUDENT PROFILE
    // ----------------------------------------------------------

    await db.collection('users').doc(user.uid).set({
      'uid': user.uid,
      'name': name.trim(),
      'email': email.trim(),
      'phone': phone.trim(),
      'semester': semester,
      'role': 'student',
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    debugPrint(
      '====================================',
    );

    debugPrint(
      'STUDENT REGISTERED',
    );

    debugPrint(
      'UID: ${user.uid}',
    );

    debugPrint(
      'Name: ${name.trim()}',
    );

    debugPrint(
      'Phone: ${phone.trim()}',
    );

    debugPrint(
      'Semester: $semester',
    );

    debugPrint(
      'Status: pending',
    );

    debugPrint(
      '====================================',
    );

    // ----------------------------------------------------------
    // IMPORTANT
    // ----------------------------------------------------------
    //
    // Registration ke baad Firebase automatically user ko
    // sign-in kar deta hai.
    //
    // Hum yahan signOut nahi kar rahe hain because tumhare
    // existing registration flow ko uske baad login screen
    // par return karna hai.
    //
    // Agar tumhara registration flow pending account ko
    // immediately logout karna chahta hai, wo RegisterScreen
    // me separately handle kar sakte hain.
  }

  // ============================================================
  // RESET PASSWORD
  // ============================================================

  Future<void> resetPassword(String email) async {
    final String cleanEmail = email.trim();

    if (cleanEmail.isEmpty) {
      throw FirebaseAuthException(
        code: 'invalid-email',
        message: 'Please enter your email address.',
      );
    }

    try {
      await auth.sendPasswordResetEmail(
        email: cleanEmail,
      );
    } on FirebaseAuthException catch (e) {
      debugPrint(
        'Password reset error: ${e.code}',
      );

      rethrow;
    }
  }

  // ============================================================
  // LOGOUT
  // ============================================================

  Future<void> logout() {
    return auth.signOut();
  }
}
