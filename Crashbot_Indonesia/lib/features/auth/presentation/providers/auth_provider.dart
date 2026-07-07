import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';

/// Manages authentication state using Firebase Auth.
/// Listens to auth state changes and notifies listeners accordingly.
class AuthProvider with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: kIsWeb
        ? '385682929993-se7ntjjuubrur3kkvmtn6uim7u4v0m8h.apps.googleusercontent.com'
        : null,
    serverClientId: '385682929993-se7ntjjuubrur3kkvmtn6uim7u4v0m8h.apps.googleusercontent.com',
  );
  User? _user;

  AuthProvider() {
    _auth.authStateChanges().listen((User? user) {
      _user = user;
      notifyListeners();
    });
  }

  User? get user => _user;
  bool get isAuthenticated => _user != null;

  /// Attempts to sign in with email and password.
  /// Returns null on success, or an error message string on failure.
  Future<String?> signIn(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      return null;
    } on FirebaseAuthException catch (e) {
      return e.message;
    }
  }

  /// Attempts to create a new account with email, password, and username.
  /// Generates a random Player ID (e.g. CB-XXXXX) and saves the profile to Firestore.
  /// Returns null on success, or an error message string on failure.
  Future<String?> signUp(String email, String password, String username) async {
    try {
      final UserCredential credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final User? user = credential.user;
      if (user != null) {
        // Generate random Player ID: CB-XXXXX (where XXXXX is a 5-digit number from 10000 to 99999)
        final int randomNum = 10000 + Random().nextInt(90000);
        final String playerId = 'CB-$randomNum';

        // Save player profile to Firestore
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'uid': user.uid,
          'email': email,
          'username': username,
          'playerId': playerId,
          'gems': 0,
          'hasSetUsername': true,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      return null;
    } on FirebaseAuthException catch (e) {
      return e.message;
    } catch (e) {
      return e.toString();
    }
  }

  /// Attempts to sign in with Google.
  /// Automatically registers new Google users in Firestore with a random Player ID.
  /// Returns null on success, or an error message string on failure.
  Future<String?> signInWithGoogle() async {
    try {
      // Trigger the authentication flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        return 'Google Sign-In aborted.';
      }

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // Create a new credential
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Once signed in, return the UserCredential
      final UserCredential userCredential = await _auth.signInWithCredential(credential);
      final User? user = userCredential.user;

      if (user != null) {
        // Check if user already exists in Firestore, if not, create their profile
        final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (!doc.exists) {
          final int randomNum = 10000 + Random().nextInt(90000);
          final String playerId = 'CB-$randomNum';

          await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
            'uid': user.uid,
            'email': user.email ?? '',
            'username': user.displayName ?? 'Player',
            'playerId': playerId,
            'gems': 0,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      }

      return null;
    } on FirebaseAuthException catch (e) {
      debugPrint('Google Sign-In FirebaseAuthException: ${e.code} - ${e.message}');
      return e.message ?? 'Firebase Auth Error';
    } catch (e, stackTrace) {
      debugPrint('Google Sign-In Error: $e');
      debugPrint('Stack Trace: $stackTrace');
      return e.toString();
    }
  }

  /// Attempts to sign in with Facebook.
  /// Automatically registers new Facebook users in Firestore with a random Player ID.
  /// Returns null on success, or an error message string on failure.
  Future<String?> signInWithFacebook() async {
    try {
      final LoginResult result = await FacebookAuth.instance.login();

      if (result.status == LoginStatus.success) {
        // Create a credential from the access token
        final OAuthCredential credential = FacebookAuthProvider.credential(result.accessToken!.tokenString);

        // Once signed in, return the UserCredential
        final UserCredential userCredential = await _auth.signInWithCredential(credential);
        final User? user = userCredential.user;

        if (user != null) {
          // Check if user already exists in Firestore, if not, create their profile
          final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
          if (!doc.exists) {
            final int randomNum = 10000 + Random().nextInt(90000);
            final String playerId = 'CB-$randomNum';

            await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
              'uid': user.uid,
              'email': user.email ?? '',
              'username': user.displayName ?? 'Player',
              'playerId': playerId,
              'gems': 0,
              'createdAt': FieldValue.serverTimestamp(),
            });
          }
        }
        return null;
      } else {
        return result.message ?? 'Facebook Sign-In aborted.';
      }
    } on FirebaseAuthException catch (e) {
      debugPrint('Facebook Sign-In FirebaseAuthException: ${e.code} - ${e.message}');
      return e.message ?? 'Firebase Auth Error';
    } catch (e, stackTrace) {
      debugPrint('Facebook Sign-In Error: $e');
      debugPrint('Stack Trace: $stackTrace');
      return e.toString();
    }
  }

  /// Signs out the currently authenticated user.
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (e) {
      debugPrint('Google SignIn signOut error: $e');
    }
    await _auth.signOut();
  }
}
