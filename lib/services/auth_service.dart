import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Google Sign-In v7.1.1: Use singleton instance
  GoogleSignIn get _googleSignIn => GoogleSignIn.instance;

  bool _isGoogleInitialized = false;

  AuthService() {
    _initializeGoogle();
  }

  User? get currentUser => _auth.currentUser;
  bool get isAuthenticated => currentUser != null;

  Future<bool> isOfflineMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('offline_mode') ?? false;
  }

  Future<void> setOfflineMode(bool offline) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('offline_mode', offline);
    notifyListeners();
  }

  Future<void> _initializeGoogle() async {
    try {
      if (!_isGoogleInitialized) {
        // Google Sign-In v7.1.1: Must call initialize() first (no parameters)
        await _googleSignIn.initialize();
        _isGoogleInitialized = true;
        debugPrint('✅ Google Sign-In initialized successfully');
      }
    } catch (e) {
      debugPrint('❌ Google Sign-In initialization error: $e');
    }
  }

  Future<UserCredential?> signInWithGoogle() async {
    try {
      // Ensure Google Sign-In is initialized
      await _initializeGoogle();

      // 1️⃣ Authenticate with Google
      final GoogleSignInAccount googleUser = await _googleSignIn.authenticate(
        scopeHint: ['email', 'profile'],
      );

      // 2️⃣ Get authentication details (synchronous in v7.1.1)
      final GoogleSignInAuthentication googleAuth = googleUser.authentication;

      // Check if we have the required ID token
      if (googleAuth.idToken == null) {
        throw FirebaseAuthException(
          code: 'missing-id-token',
          message: 'Failed to retrieve ID token from Google Sign-In.',
        );
      }

      // 3️⃣ Get authorization for access token (if needed)
      GoogleSignInClientAuthorization? authz;
      try {
        final authClient = _googleSignIn.authorizationClient;
        authz = await authClient.authorizationForScopes(['email', 'profile']);
      } catch (e) {
        debugPrint('Authorization step failed: $e');
        // Continue without access token if authorization fails
      }

      // 4️⃣ Create Firebase credential
      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
        accessToken: authz?.accessToken, // This might be null, which is okay
      );

      // 5️⃣ Sign in to Firebase
      final UserCredential userCredential = await _auth.signInWithCredential(
        credential,
      );

      // 6️⃣ Set offline mode to false and notify listeners
      await setOfflineMode(false);
      notifyListeners();

      debugPrint('✅ Google sign-in successful: ${userCredential.user?.email}');
      return userCredential;
    } on GoogleSignInException catch (e) {
      debugPrint('🔥 Google Sign-In Error: ${e.code.name} - ${e.description}');
      return null;
    } on FirebaseAuthException catch (e) {
      debugPrint('🔥 Firebase Auth Error: ${e.code} - ${e.message}');
      return null;
    } catch (e) {
      debugPrint('❌ Google sign in error: $e');
      return null;
    }
  }

  // Alternative simpler method if you don't need authorization scopes
  Future<UserCredential?> signInWithGoogleSimple() async {
    try {
      // Ensure Google Sign-In is initialized
      await _initializeGoogle();

      // 1️⃣ Authenticate with Google (throws exception if canceled)
      final GoogleSignInAccount googleUser = await _googleSignIn.authenticate();

      // 2️⃣ Get authentication details (synchronous in v7.1.1)
      final GoogleSignInAuthentication googleAuth = googleUser.authentication;

      // 3️⃣ Create Firebase credential (without access token)
      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      // 4️⃣ Sign in to Firebase
      final UserCredential userCredential = await _auth.signInWithCredential(
        credential,
      );

      await setOfflineMode(false);
      notifyListeners();

      debugPrint('✅ Google sign-in successful: ${userCredential.user?.email}');
      return userCredential;
    } on GoogleSignInException catch (e) {
      debugPrint('🔥 Google Sign-In Error: ${e.code.name} - ${e.description}');
      return null;
    } catch (e) {
      debugPrint('❌ Google sign in error: $e');
      return null;
    }
  }

  // Sign Out
  Future<void> signOut() async {
    try {
      await Future.wait([_auth.signOut(), _googleSignIn.signOut()]);
      notifyListeners();
      debugPrint('✅ Sign out successful');
    } catch (e) {
      debugPrint('❌ Sign out error: $e');
    }
  }

  // Continue as Guest (Offline Mode)
  Future<void> continueAsGuest() async {
    await setOfflineMode(true);
    notifyListeners();
    debugPrint('✅ Continuing as guest (offline mode)');
  }

  // Check if user is signed in with Google
  bool get isSignedInWithGoogle {
    return currentUser?.providerData.any(
          (info) => info.providerId == 'google.com',
        ) ??
        false;
  }

  // Get user display info
  String? get userDisplayName => currentUser?.displayName;
  String? get userEmail => currentUser?.email;
  String? get userPhotoURL => currentUser?.photoURL;

  // Check if Google Sign-In is properly initialized
  bool get isGoogleInitialized => _isGoogleInitialized;
}
