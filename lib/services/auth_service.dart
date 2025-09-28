import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

class AuthService {
  final fb.FirebaseAuth _firebaseAuth = fb.FirebaseAuth.instance;
  final SupabaseService _supabaseService = SupabaseService();

  Future<fb.User?> signInWithEmail(String email, String password) async {
  try {
    fb.UserCredential userCredential = await _firebaseAuth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    // Sync user data to Supabase hanya jika user berhasil login
    if (userCredential.user != null) {
      try {
        await _syncUserToSupabase(userCredential.user!);
      } catch (e) {
        print("Error syncing to Supabase: $e");
        // Jangan return null hanya karena sync gagal, user tetap bisa login
      }
    }

    return userCredential.user;
  } catch (e) {
    print("Error signing in: $e");
    return null;
  }
}

  Future<fb.User?> registerWithEmail(String email, String password) async {
    try {
      fb.UserCredential userCredential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      return userCredential.user;
    } catch (e) {
      print("Error registering: $e");
      return null;
    }
  }

  Future<void> signOut() async {
    await _firebaseAuth.signOut();
  }

  Future<void> _syncUserToSupabase(fb.User firebaseUser) async {
    final userData = {
      'uid': firebaseUser.uid,
      'email': firebaseUser.email,
      'createdat': DateTime.now().toIso8601String(),
    };

    await _supabaseService.client.from('users').upsert(userData);
  }
}