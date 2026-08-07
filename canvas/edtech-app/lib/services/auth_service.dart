import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_profile.dart';
import 'database_service.dart';
import 'supabase_service.dart';

class AuthService {
  /// Stable local id used for a "Skip for now" guest session (no Firebase
  /// account). The profile is stored locally under this id so it survives
  /// app restarts instead of resetting to onboarding every time.
  static const String guestUserId = 'guest_user';

  // Lazy getters to avoid accessing Firebase in constructor
  FirebaseAuth get _auth {
    try {
      return FirebaseAuth.instance;
    } catch (e) {
      throw Exception(
          'Firebase not initialized. Please configure Firebase first.');
    }
  }

  GoogleSignIn get _googleSignIn => GoogleSignIn();
  DatabaseService get _dbService => DatabaseService();

  // Get current user
  User? get currentUser {
    try {
      return _auth.currentUser;
    } catch (e) {
      print('Firebase not available: $e');
      return null;
    }
  }

  // Auth state changes stream
  Stream<User?> get authStateChanges {
    try {
      return _auth.authStateChanges();
    } catch (e) {
      print('Firebase not available: $e');
      return Stream.value(null);
    }
  }

  // Sign in with Google
  Future<UserProfile?> signInWithGoogle() async {
    try {
      // Trigger the Google Sign-In flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        // User canceled the sign-in
        return null;
      }

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // Create a new credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with the Google credential
      final UserCredential userCredential =
          await _auth.signInWithCredential(credential);
      final User? user = userCredential.user;

      if (user != null) {
        return await _createOrUpdateUserProfile(user);
      }

      return null;
    } catch (e) {
      print('Error signing in with Google: $e');
      rethrow;
    }
  }

  // Helper method to create or update user profile
  Future<UserProfile> _createOrUpdateUserProfile(User user) async {
    // CRITICAL: Set Firebase user ID in SupabaseService so it can be used for all Supabase operations
    SupabaseService.setFirebaseUserId(user.uid);

    // Check if user profile exists
    UserProfile? profile = await _dbService.getUserProfile(user.uid);

    if (profile == null) {
      // Create new user profile
      profile = UserProfile(
        id: user.uid,
        name: user.displayName ?? 'User',
        email: user.email ?? '',
        lastActiveDate: DateTime.now(),
        photoUrl: user.photoURL,
      );

      await _dbService.saveUserProfile(profile);
    } else {
      // Update last active date and streak
      profile.lastActiveDate = DateTime.now();
      await _dbService.updateUserProfile(profile);
    }

    // Save login state
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', true);
    await prefs.setString('userId', user.uid);

    return profile;
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      await _auth.signOut();

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('isLoggedIn');
      await prefs.remove('userId');
    } catch (e) {
      print('Error signing out: $e');
      throw Exception('Failed to sign out: $e');
    }
  }

  // Check if user is logged in
  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('isLoggedIn') ?? false;
  }

  // Get current user profile
  Future<UserProfile?> getCurrentUserProfile() async {
    final user = currentUser;
    if (user != null) {
      return await _dbService.getUserProfile(user.uid);
    }
    // No Firebase account signed in — this may be a guest ("Skip for now")
    // session. Fall back to whatever guest profile is stored locally so it
    // survives app restarts instead of resetting to onboarding.
    return await _dbService.getUserProfile(guestUserId);
  }

  // Update user profile
  Future<void> updateUserProfile(UserProfile profile) async {
    await _dbService.updateUserProfile(profile);
  }

  // Delete account
  Future<void> deleteAccount() async {
    try {
      final user = currentUser;
      if (user != null) {
        // Delete user data from database
        await _dbService.deleteUserData(user.uid);

        // Delete Firebase user
        await user.delete();

        // Sign out from Google
        await _googleSignIn.signOut();

        // Clear preferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.clear();
      }
    } catch (e) {
      print('Error deleting account: $e');
      throw Exception('Failed to delete account: $e');
    }
  }
}
