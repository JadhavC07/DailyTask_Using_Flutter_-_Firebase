import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:myapp/services/crashlytics_service.dart';

class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Google Sign-In v7.1.1: Use singleton instance
  GoogleSignIn get _googleSignIn => GoogleSignIn.instance;

  bool _isGoogleInitialized = false;

  AuthService() {
    _initializeGoogle();

    // Listen for auth state changes and update Crashlytics user info
    _auth.authStateChanges().listen((User? user) {
      CrashlyticsService.setUserInfo();
    });
  }

  User? get currentUser => _auth.currentUser;
  bool get isAuthenticated => currentUser != null;

  Future<bool> isOfflineMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('offline_mode') ?? false;
  }

  Future<void> setOfflineMode(bool offline) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('offline_mode', offline);

      await CrashlyticsService.recordAuthEvent(
        'offline_mode_changed',
        success: true,
      );
      await CrashlyticsService.setCustomKey('offline_mode', offline);

      notifyListeners();
    } catch (e, stackTrace) {
      await CrashlyticsService.recordError(
        exception: e,
        stackTrace: stackTrace,
        reason: 'Failed to set offline mode',
        fatal: false,
      );
    }
  }

  Future<void> _initializeGoogle() async {
    try {
      if (!_isGoogleInitialized) {
        // Google Sign-In v7.1.1: Must call initialize() first (no parameters)
        await _googleSignIn.initialize();
        _isGoogleInitialized = true;
        debugPrint('✅ Google Sign-In initialized successfully');

        await CrashlyticsService.recordAuthEvent(
          'google_signin_initialized',
          method: 'google',
          success: true,
        );
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Google Sign-In initialization error: $e');
      await CrashlyticsService.recordError(
        exception: e,
        stackTrace: stackTrace,
        reason: 'Google Sign-In initialization failed',
        fatal: false,
      );
    }
  }

  Future<UserCredential?> signInWithGoogle() async {
    try {
      await CrashlyticsService.log('Starting Google sign-in process');

      // Ensure Google Sign-In is initialized
      await _initializeGoogle();

      // 1️⃣ Authenticate with Google
      final GoogleSignInAccount googleUser = await _googleSignIn.authenticate(
        scopeHint: ['email', 'profile'],
      );

      await CrashlyticsService.log('Google authentication successful');

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
        await CrashlyticsService.recordError(
          exception: e,
          reason: 'Google authorization step failed',
          fatal: false,
        );
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

      // Update Crashlytics with successful sign-in
      await CrashlyticsService.recordAuthEvent(
        'google_signin_success',
        method: 'google',
        success: true,
      );
      await CrashlyticsService.setUserInfo();

      debugPrint('✅ Google sign-in successful: ${userCredential.user?.email}');
      return userCredential;
    } on GoogleSignInException catch (e, stackTrace) {
      debugPrint('🔥 Google Sign-In Error: ${e.code.name} - ${e.description}');

      await CrashlyticsService.recordError(
        exception: e,
        stackTrace: stackTrace,
        reason: 'Google Sign-In failed: ${e.code.name}',
        fatal: false,
      );
      await CrashlyticsService.recordAuthEvent(
        'google_signin_failed',
        method: 'google',
        success: false,
      );

      return null;
    } on FirebaseAuthException catch (e, stackTrace) {
      debugPrint('🔥 Firebase Auth Error: ${e.code} - ${e.message}');

      await CrashlyticsService.recordError(
        exception: e,
        stackTrace: stackTrace,
        reason: 'Firebase Auth failed: ${e.code}',
        fatal: false,
      );
      await CrashlyticsService.recordAuthEvent(
        'firebase_auth_failed',
        method: 'google',
        success: false,
      );

      return null;
    } catch (e, stackTrace) {
      debugPrint('❌ Google sign in error: $e');

      await CrashlyticsService.recordError(
        exception: e,
        stackTrace: stackTrace,
        reason: 'Unexpected Google sign-in error',
        fatal: false,
      );
      await CrashlyticsService.recordAuthEvent(
        'signin_unexpected_error',
        method: 'google',
        success: false,
      );

      return null;
    }
  }

  // Alternative simpler method if you don't need authorization scopes
  Future<UserCredential?> signInWithGoogleSimple() async {
    try {
      await CrashlyticsService.log('Starting simple Google sign-in process');

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

      await CrashlyticsService.recordAuthEvent(
        'google_signin_simple_success',
        method: 'google_simple',
        success: true,
      );
      await CrashlyticsService.setUserInfo();

      debugPrint('✅ Google sign-in successful: ${userCredential.user?.email}');
      return userCredential;
    } on GoogleSignInException catch (e, stackTrace) {
      debugPrint('🔥 Google Sign-In Error: ${e.code.name} - ${e.description}');

      await CrashlyticsService.recordError(
        exception: e,
        stackTrace: stackTrace,
        reason: 'Simple Google Sign-In failed: ${e.code.name}',
        fatal: false,
      );
      await CrashlyticsService.recordAuthEvent(
        'google_signin_simple_failed',
        method: 'google_simple',
        success: false,
      );

      return null;
    } catch (e, stackTrace) {
      debugPrint('❌ Google sign in error: $e');

      await CrashlyticsService.recordError(
        exception: e,
        stackTrace: stackTrace,
        reason: 'Unexpected simple Google sign-in error',
        fatal: false,
      );

      return null;
    }
  }

  // Sign Out
  Future<void> signOut() async {
    try {
      await CrashlyticsService.log('Starting sign out process');

      await Future.wait([_auth.signOut(), _googleSignIn.signOut()]);

      await CrashlyticsService.recordAuthEvent(
        'signout_success',
        success: true,
      );
      await CrashlyticsService.setUserInfo(); // This will clear user info

      notifyListeners();
      debugPrint('✅ Sign out successful');
    } catch (e, stackTrace) {
      debugPrint('❌ Sign out error: $e');

      await CrashlyticsService.recordError(
        exception: e,
        stackTrace: stackTrace,
        reason: 'Sign out failed',
        fatal: false,
      );
      await CrashlyticsService.recordAuthEvent(
        'signout_failed',
        success: false,
      );
    }
  }

  // Continue as Guest (Offline Mode)
  Future<void> continueAsGuest() async {
    try {
      await setOfflineMode(true);

      await CrashlyticsService.recordAuthEvent(
        'guest_mode_enabled',
        method: 'guest',
        success: true,
      );
      await CrashlyticsService.log('User continued as guest');

      notifyListeners();
      debugPrint('✅ Continuing as guest (offline mode)');
    } catch (e, stackTrace) {
      await CrashlyticsService.recordError(
        exception: e,
        stackTrace: stackTrace,
        reason: 'Failed to continue as guest',
        fatal: false,
      );
    }
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
