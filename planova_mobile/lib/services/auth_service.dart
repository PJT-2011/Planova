import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // ── Sign up ───────────────────────────────────────────────────────────────
  Future<UserCredential?> signUpWithEmailPassword({
    required String email,
    required String password,
    required String name,
    String role = 'admin',
  }) async {
    try {
      UserCredential userCredential = await _auth
          .createUserWithEmailAndPassword(email: email, password: password);

      await userCredential.user?.sendEmailVerification();

      await _firestore.collection('users').doc(userCredential.user!.uid).set({
        'userId': userCredential.user!.uid,
        'email': email,
        'name': name,
        'role': role,
        'photoUrl': null,
        'createdAt': FieldValue.serverTimestamp(),
        'lastLogin': FieldValue.serverTimestamp(),
        'isActive': true,
        'provider': 'email',
      });

      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw 'An unexpected error occurred. Please try again.';
    }
  }

  // ── Sign in with email / password ─────────────────────────────────────────
  Future<UserCredential?> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // ✅ use set+merge so it works even if the doc was deleted
      await _firestore.collection('users').doc(userCredential.user!.uid).set({
        'lastLogin': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw 'An unexpected error occurred. Please try again.';
    }
  }

  // ── Sign in anonymously (guest) ───────────────────────────────────────────
  Future<UserCredential> signInAnonymously() async {
    try {
      final credential = await _auth.signInAnonymously();
      debugPrint('✅ [AuthService] Anonymous sign-in: ${credential.user?.uid}');
      return credential;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw 'Failed to continue as guest. Please try again.';
    }
  }

  // ── Sign in with Google ───────────────────────────────────────────────────
  Future<UserCredential?> signInWithGoogle() async {
    try {
      debugPrint('🔵 [Google] Starting sign-in...');
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        debugPrint('🟡 [Google] User cancelled picker');
        return null;
      }

      debugPrint('🔵 [Google] Got account: ${googleUser.email}');
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await _auth.signInWithCredential(
        credential,
      );

      final user = userCredential.user!;
      final isNewUser = userCredential.additionalUserInfo?.isNewUser ?? false;

      if (isNewUser) {
        await _firestore.collection('users').doc(user.uid).set({
          'userId': user.uid,
          'email': user.email ?? '',
          'name': user.displayName ?? 'Google User',
          'role': 'admin',
          'photoUrl': user.photoURL,
          'createdAt': FieldValue.serverTimestamp(),
          'lastLogin': FieldValue.serverTimestamp(),
          'isActive': true,
          'provider': 'google',
        });
      } else {
        // ✅ use set+merge so it works even if the doc was deleted
        await _firestore.collection('users').doc(user.uid).set({
          'lastLogin': FieldValue.serverTimestamp(),
          'photoUrl': user.photoURL,
        }, SetOptions(merge: true));
      }

      return userCredential;
    } on FirebaseAuthException catch (e) {
      debugPrint('🔴 [Google] FirebaseAuthException: ${e.code} - ${e.message}');
      throw _handleAuthException(e);
    } catch (e) {
      debugPrint('🔴 [Google] Unknown error: $e');
      throw 'Google sign-in failed: $e';
    }
  }

  // ── Sign out ──────────────────────────────────────────────────────────────
  Future<void> signOut() async {
    try {
      if (await _googleSignIn.isSignedIn()) {
        await _googleSignIn.signOut();
      }
      await _auth.signOut();
    } catch (e) {
      throw 'Failed to sign out. Please try again.';
    }
  }

  // ── Send email verification ───────────────────────────────────────────────
  Future<void> sendEmailVerification() async {
    try {
      await _auth.currentUser?.sendEmailVerification();
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  // ── Check if email is verified ────────────────────────────────────────────
  Future<bool> isEmailVerified() async {
    await _auth.currentUser?.reload();
    return _auth.currentUser?.emailVerified ?? false;
  }

  // ── Send password reset email ─────────────────────────────────────────────
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  // ── Get user data ─────────────────────────────────────────────────────────
  Future<Map<String, dynamic>?> getUserData(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) return doc.data() as Map<String, dynamic>;
      return null;
    } catch (e) {
      return null;
    }
  }

  // ── Update display name ───────────────────────────────────────────────────
  Future<void> updateName(String userId, String newName) async {
    // ✅ use set+merge so it works even if the doc was deleted
    await _firestore.collection('users').doc(userId).set({
      'name': newName,
    }, SetOptions(merge: true));
  }

  // ── Upload profile photo ──────────────────────────────────────────────────
  Future<String> updatePhoto(String userId, File imageFile) async {
    final ref = _storage.ref('profile_photos/$userId.jpg');
    await ref.putFile(imageFile, SettableMetadata(contentType: 'image/jpeg'));
    final url = await ref.getDownloadURL();
    // ✅ use set+merge so it works even if the doc was deleted
    await _firestore.collection('users').doc(userId).set({
      'photoUrl': url,
    }, SetOptions(merge: true));
    return url;
  }

  // ── Auth exception handler ────────────────────────────────────────────────
  String _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'weak-password':
        return 'The password is too weak. Use at least 6 characters.';
      case 'email-already-in-use':
        return 'An account already exists with this email.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'user-not-found':
        return 'No account found with this email.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'account-exists-with-different-credential':
        return 'An account already exists with a different sign-in method for this email.';
      case 'operation-not-allowed':
        return 'Guest access is not enabled. Please contact support.';
      default:
        return 'Authentication failed: ${e.message}';
    }
  }
}
