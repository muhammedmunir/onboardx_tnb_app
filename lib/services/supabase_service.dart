import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  final SupabaseClient client = Supabase.instance.client;

  // Get user by uid (returns null if not found)
  Future<Map<String, dynamic>?> getUser(String uid) async {
    try {
      final response = await client
          .from('users')
          .select()
          .eq('uid', uid)
          .maybeSingle(); // <-- returns null if 0 rows
      if (response == null) return null;
      return Map<String, dynamic>.from(response as Map);
    } catch (e) {
      print('Failed to get user: $e');
      throw Exception('Failed to get user: $e');
    }
  }

  // Create user and return inserted row (or throw on error)
  Future<Map<String, dynamic>> createUser(Map<String, dynamic> userData) async {
    try {
      // Optionally check username first
      if (userData.containsKey('username') && userData['username'] != null) {
        final exists = await isUsernameExists(userData['username'] as String);
        if (exists) {
          throw Exception('Username already taken');
        }
      }

      final inserted = await client
          .from('users')
          .insert(userData)
          .select()
          .maybeSingle(); // should return the inserted row

      if (inserted == null) {
        throw Exception('Insert returned no row');
      }

      return Map<String, dynamic>.from(inserted as Map);
    } catch (e) {
      print('Failed to create user: $e');
      throw Exception('Failed to create user: $e');
    }
  }

  Future<void> updateUser(String uid, Map<String, dynamic> updates) async {
    try {
      await client.from('users').update(updates).eq('uid', uid);
    } catch (e) {
      print('Failed to update user: $e');
      throw Exception('Failed to update user: $e');
    }
  }

  Future<bool> isUsernameExists(String username) async {
    try {
      final response = await client
          .from('users')
          .select('username')
          .eq('username', username)
          .limit(1)
          .maybeSingle();
      return response != null;
    } catch (e) {
      print('Failed to check username: $e');
      throw Exception('Failed to check username: $e');
    }
  }

  // File upload operations - UPDATED FOR profile-images BUCKET
  Future<String> uploadFile(String bucket, String path, File file) async {
    try {
      final response = await client.storage.from(bucket).upload(path, file);
      return response;
    } catch (e) {
      print('Failed to upload file to bucket $bucket, path $path: $e');
      throw Exception('Failed to upload file: $e');
    }
  }

  // NEW: Upload file with overwrite option
  Future<String> uploadFileWithOverwrite(String bucket, String path, File file) async {
    try {
      final response = await client.storage.from(bucket).upload(
        path, 
        file,
        fileOptions: const FileOptions(upsert: true),
      );
      return response;
    } catch (e) {
      print('Failed to upload file with overwrite to bucket $bucket, path $path: $e');
      throw Exception('Failed to upload file: $e');
    }
  }

  Future<String> getPublicUrl(String bucket, String path) async {
    try {
      return client.storage.from(bucket).getPublicUrl(path);
    } catch (e) {
      print('Failed to get public URL for bucket $bucket, path $path: $e');
      throw Exception('Failed to get public URL: $e');
    }
  }

  // NEW: Check if file exists in storage
  Future<bool> fileExists(String bucket, String path) async {
    try {
      final response = await client.storage.from(bucket).list(path: path);
      return response.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  // Delete file from storage
  Future<void> deleteFile(String bucket, String path) async {
    try {
      await client.storage.from(bucket).remove([path]);
    } catch (e) {
      print('Failed to delete file from bucket $bucket, path $path: $e');
      throw Exception('Failed to delete file: $e');
    }
  }

  // NEW: Update user profile with image
  Future<void> updateUserProfile({
    required String uid,
    required String fullName,
    required String username,
    required String phoneNumber,
    String? profileImagePath,
  }) async {
    try {
      final updateData = {
        'full_name': fullName,
        'username': username,
        'phone_number': phoneNumber,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
        if (profileImagePath != null) 'profile_image': profileImagePath,
      };

      await updateUser(uid, updateData);
    } catch (e) {
      print('Failed to update user profile: $e');
      throw Exception('Failed to update user profile: $e');
    }
  }

  // NEW: Upload profile image and return the path
  Future<String> uploadProfileImage(String uid, File imageFile) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = '${uid}_$timestamp.jpg';
      final path = 'profiles/$fileName';
      
      await uploadFileWithOverwrite('profile-images', path, imageFile);
      return path;
    } catch (e) {
      print('Failed to upload profile image: $e');
      throw Exception('Failed to upload profile image: $e');
    }
  }

  // NEW: Get user profile with image URL
  Future<Map<String, dynamic>?> getUserProfile(String uid) async {
  try {
    final userData = await getUser(uid);
    if (userData == null) return null;

    // Add profile image URL if exists
    if (userData['profile_image'] != null && (userData['profile_image'] as String).isNotEmpty) {
      try {
        // getPublicUrl is synchronous, no need for await
        userData['profile_image_url'] = getPublicUrl('profile-images', userData['profile_image'] as String);
        print('🖼 Profile image URL: ${userData['profile_image_url']}');
      } catch (e) {
        print('❌ Error generating profile image URL: $e');
        userData['profile_image_url'] = null;
      }
    } else {
      print('ℹ No profile image found for user');
      userData['profile_image_url'] = null;
    }

    return userData;
  } catch (e) {
    print('❌ Failed to get user profile: $e');
    throw Exception('Failed to get user profile: $e');
  }
}

  // Projects operations
  Future<List<Map<String, dynamic>>> getProjects() async {
    try {
      final response = await client.from('projects').select();
      return response;
    } catch (e) {
      print('Failed to get projects: $e');
      throw Exception('Failed to get projects: $e');
    }
  }

  // Tasks operations
  Future<List<Map<String, dynamic>>> getTasks() async {
    try {
      final response = await client.from('tasks').select('''
        *,
        projects (*)
      ''');
      return response;
    } catch (e) {
      print('Failed to get tasks: $e');
      throw Exception('Failed to get tasks: $e');
    }
  }

  // Learning operations
  Future<List<Map<String, dynamic>>> getLearnings() async {
    try {
      final response = await client.from('learns').select('''
        *,
        lessons (*)
      ''');
      return response;
    } catch (e) {
      print('Failed to get learnings: $e');
      throw Exception('Failed to get learnings: $e');
    }
  }

  // Progress tracking
  Future<void> updateProgress(Map<String, dynamic> progressData) async {
    try {
      await client.from('progress').upsert(progressData);
    } catch (e) {
      print('Failed to update progress: $e');
      throw Exception('Failed to update progress: $e');
    }
  }

  // Get user progress
  Future<List<Map<String, dynamic>>> getUserProgress(String userId) async {
    try {
      final response = await client
          .from('progress')
          .select('''
            *,
            lessons (*),
            learns (*)
          ''')
          .eq('userId', userId);
      return response;
    } catch (e) {
      print('Failed to get user progress: $e');
      throw Exception('Failed to get user progress: $e');
    }
  }
}