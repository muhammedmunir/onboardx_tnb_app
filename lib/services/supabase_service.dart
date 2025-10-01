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
          .maybeSingle();
      if (response == null) return null;
      return Map<String, dynamic>.from(response as Map);
    } catch (e) {
      print('❌ Failed to get user: $e');
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
          .maybeSingle();

      if (inserted == null) {
        throw Exception('Insert returned no row');
      }

      return Map<String, dynamic>.from(inserted as Map);
    } catch (e) {
      print('❌ Failed to create user: $e');
      throw Exception('Failed to create user: $e');
    }
  }

  Future<void> updateUser(String uid, Map<String, dynamic> updates) async {
    try {
      await client.from('users').update(updates).eq('uid', uid);
    } catch (e) {
      print('❌ Failed to update user: $e');
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
      print('❌ Failed to check username: $e');
      throw Exception('Failed to check username: $e');
    }
  }

  // File upload operations
  Future<String> uploadFile(String bucket, String path, File file) async {
    try {
      print('📤 Uploading file to bucket: $bucket, path: $path');
      
      final response = await client.storage.from(bucket).upload(path, file);
      
      print('✅ File uploaded successfully: $response');
      return response;
    } catch (e) {
      print('❌ Failed to upload file to bucket $bucket, path $path: $e');
      throw Exception('Failed to upload file: ${e.toString()}');
    }
  }

  // Upload file with overwrite option
  Future<String> uploadFileWithOverwrite(String bucket, String path, File file) async {
    try {
      print('📤 Uploading file with overwrite to bucket: $bucket, path: $path');
      
      final response = await client.storage.from(bucket).upload(
        path, 
        file,
        fileOptions: const FileOptions(upsert: true),
      );
      
      print('✅ File uploaded with overwrite successfully: $response');
      return response;
    } catch (e) {
      print('❌ Failed to upload file with overwrite to bucket $bucket, path $path: $e');
      throw Exception('Failed to upload file: ${e.toString()}');
    }
  }

  // UBAH INI: getPublicUrl menjadi synchronous karena di Supabase ini synchronous operation
  String getPublicUrl(String bucket, String path) {
    try {
      final url = client.storage.from(bucket).getPublicUrl(path);
      print('🔗 Generated public URL: $url');
      return url;
    } catch (e) {
      print('❌ Failed to get public URL for bucket $bucket, path $path: $e');
      throw Exception('Failed to get public URL: $e');
    }
  }

  // Check if file exists in storage
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
      print('🗑 File deleted: $path from bucket: $bucket');
    } catch (e) {
      print('❌ Failed to delete file from bucket $bucket, path $path: $e');
      throw Exception('Failed to delete file: $e');
    }
  }

  // Update user profile with image
  Future<void> updateUserProfile({
    required String uid,
    required String fullName,
    required String username,
    required String phoneNumber,
    String? profileImagePath,
  }) async {
    try {
      print('👤 Updating user profile for: $uid');
      
      final updateData = {
        'full_name': fullName,
        'username': username,
        'phone_number': phoneNumber,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
        if (profileImagePath != null) 'profile_image': profileImagePath,
      };

      await updateUser(uid, updateData);
      print('✅ User profile updated successfully');
    } catch (e) {
      print('❌ Failed to update user profile: $e');
      throw Exception('Failed to update user profile: $e');
    }
  }

  // Upload profile image and return the path
  Future<String> uploadProfileImage(String uid, File imageFile) async {
    try {
      print('🖼 Starting profile image upload for user: $uid');
      
      // Validate file
      if (!await imageFile.exists()) {
        throw Exception('Image file does not exist');
      }

      final fileSize = await imageFile.length();
      if (fileSize > 5 * 1024 * 1024) {
        throw Exception('Image file too large. Maximum size is 5MB.');
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'profile_$timestamp.jpg';
      final path = 'profiles/$uid/$fileName';
      
      print('📁 Uploading to path: $path');
      
      final result = await uploadFileWithOverwrite('profile-images', path, imageFile);
      
      print('✅ Profile image uploaded successfully: $result');
      return path;
    } catch (e) {
      print('❌ Failed to upload profile image: $e');
      throw Exception('Failed to upload profile image: ${e.toString()}');
    }
  }

  // PERBAIKAN UTAMA: Get user profile with image URL - TAMBAHKAN AWAIT
  Future<Map<String, dynamic>?> getUserProfile(String uid) async {
    try {
      final userData = await getUser(uid);
      if (userData == null) return null;

      // Add profile image URL if exists - INI PERBAIKAN UTAMA
      if (userData['profile_image'] != null && userData['profile_image'].isNotEmpty) {
        // TAMBAHKAN AWAIT di sini karena getPublicUrl sekarang synchronous
        userData['profile_image_url'] = getPublicUrl('profile-images', userData['profile_image']);
        print('🖼 Profile image URL: ${userData['profile_image_url']}');
      } else {
        print('ℹ No profile image found for user');
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
      print('❌ Failed to get projects: $e');
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
      print('❌ Failed to get tasks: $e');
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
      print('❌ Failed to get learnings: $e');
      throw Exception('Failed to get learnings: $e');
    }
  }

  // Progress tracking
  Future<void> updateProgress(Map<String, dynamic> progressData) async {
    try {
      await client.from('progress').upsert(progressData);
    } catch (e) {
      print('❌ Failed to update progress: $e');
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
      print('❌ Failed to get user progress: $e');
      throw Exception('Failed to get user progress: $e');
    }
  }
}