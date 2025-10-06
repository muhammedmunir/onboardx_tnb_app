import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  final SupabaseClient client = Supabase.instance.client;

  // List of supported image formats
  static const List<String> supportedImageFormats = [
    'jpg',
    'jpeg',
    'png',
    'gif',
    'bmp',
    'webp',
    'heic',
    'heif'
  ];

  // Maximum file size (10MB)
  static const int maxFileSize = 10 * 1024 * 1024;

  // Get user by uid (returns null if not found)
  Future<Map<String, dynamic>?> getUser(String uid) async {
    try {
      final response =
          await client.from('users').select().eq('uid', uid).maybeSingle();
      if (response == null) return null;
      return Map<String, dynamic>.from(response as Map);
    } catch (e) {
      print('❌ Failed to get user: $e');
      throw Exception('Failed to get user: $e');
    }
  }

  Future<Map<String, dynamic>?> getUserProfileForApp(String uid) async {
    try {
      final user =
          await getUser(uid); // existing method yang return snake_case map
      if (user == null) return null;

      // Build camelCase map
      final Map<String, dynamic> out = {
        'uid': user['uid'],
        'fullName': user['full_name'] ?? '',
        'username': user['username'] ?? '',
        'email': user['email'] ?? '',
        'phoneNumber': user['phone_number'] ?? '',
        'workType': user['work_type'] ?? '',
        'workplace': user['workplace'] ?? '',
        // keep legacy workUnit key if UI expects it — we'll map to team.work_team if available
        'workUnit':
            user['work_unit'] ?? user['work_unit'], // placeholder if exists
      };

      // If user has team_id, fetch team by no_team
      if (user['team_id'] != null) {
        try {
          final team = await getTeamByNoTeam(user['team_id'].toString());
          if (team != null) {
            out['workUnit'] = team['work_team'] ?? out['workUnit'] ?? '';
            out['workTeam'] = team['work_team'] ?? '';
            out['workPlace'] = team['work_place'] ?? '';
            // also keep workplace if user.workplace was empty
            if ((out['workplace'] == null ||
                    out['workplace'].toString().isEmpty) &&
                (team['work_place'] != null)) {
              out['workplace'] = team['work_place'];
            }
          }
        } catch (e) {
          print('⚠ Failed to fetch team info for user $uid: $e');
        }
      }

      // profile image -> public url
      if (user['profile_image'] != null &&
          (user['profile_image'] as String).isNotEmpty) {
        try {
          // getPublicUrl is synchronous in your file; returns url string
          out['profileImageUrl'] =
              getPublicUrl('profile-images', user['profile_image']);
        } catch (e) {
          print('⚠ Failed to generate profile image URL: $e');
        }
      }

      return out;
    } catch (e) {
      print('❌ getUserProfileForApp failed: $e');
      throw Exception('Failed to get user profile for app: $e');
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

      final inserted =
          await client.from('users').insert(userData).select().maybeSingle();

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

  Future<Map<String, dynamic>?> getTeamByNoTeam(String noTeam) async {
    try {
      final response = await client
          .from('teams')
          .select()
          .eq('no_team', noTeam) // Cari berdasarkan no_team bukan team_id
          .maybeSingle();
      return response;
    } catch (e) {
      print('❌ Failed to get team by no_team: $e');
      throw Exception('Failed to get team by no_team: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getAllTeams() async {
    try {
      final response = await client.from('teams').select().order('no_team');
      return response;
    } catch (e) {
      print('❌ Failed to get teams: $e');
      throw Exception('Failed to get teams: $e');
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
  Future<String> uploadFileWithOverwrite(
      String bucket, String path, File file) async {
    try {
      print('📤 Uploading file to bucket: $bucket, path: $path');

      // Check file size before upload
      final fileSize = await file.length();
      if (fileSize > maxFileSize) {
        throw Exception(
            'File size too large. Maximum allowed: ${maxFileSize ~/ (1024 * 1024)}MB');
      }

      final response = await client.storage.from(bucket).upload(
            path,
            file,
            fileOptions: const FileOptions(upsert: true),
          );

      print('✅ File uploaded with overwrite successfully: $response');
      return response;
    } on StorageException catch (e) {
      print('❌ StorageException during upload: $e');
      if (e.message.contains('File size limit exceeded')) {
        throw Exception(
            'File too large. Maximum size is ${maxFileSize ~/ (1024 * 1024)}MB.');
      }
      throw Exception('Failed to upload file: ${e.message}');
    } catch (e) {
      print(
          '❌ Failed to upload file with overwrite to bucket $bucket, path $path: $e');
      throw Exception('Failed to upload file: ${e.toString()}');
    }
  }

  // getPublicUrl menjadi synchronous karena di Supabase ini synchronous operation
  String getPublicUrl(String bucket, String path) {
    try {
      // PERBAIKAN: Bersihkan path dari awalan bucket jika ada
      String cleanPath = path;
      if (cleanPath.startsWith('$bucket/')) {
        cleanPath = cleanPath.substring(bucket.length + 1);
      }
      if (cleanPath.startsWith('/')) {
        cleanPath = cleanPath.substring(1);
      }

      final url = client.storage.from(bucket).getPublicUrl(cleanPath);
      print('🔗 Generated public URL for $bucket: $url');
      return url;
    } catch (e) {
      print('❌ Failed to get public URL for bucket $bucket, path $path: $e');
      throw Exception('Failed to get public URL: $e');
    }
  }

  // Check if file exists in storage
  Future<bool> fileExists(String bucket, String path) async {
    try {
      // Try to download the file (most reliable way to check existence)
      await client.storage.from(bucket).download(path);
      return true;
    } catch (e) {
      // If any error occurs, file likely doesn't exist
      print('File does not exist: $path, error: $e');
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

  // Validate image file
  Future<void> _validateImageFile(File imageFile) async {
    // Check if file exists
    if (!await imageFile.exists()) {
      throw Exception('Image file does not exist');
    }

    // Check file size
    final fileSize = await imageFile.length();
    if (fileSize > maxFileSize) {
      throw Exception(
          'Image file too large. Maximum size is ${maxFileSize ~/ (1024 * 1024)}MB.');
    }

    // Check file extension
    final fileExtension = imageFile.path.split('.').last.toLowerCase();
    if (!supportedImageFormats.contains(fileExtension)) {
      throw Exception(
          'Unsupported image format. Supported formats: ${supportedImageFormats.join(', ')}');
    }
  }

  // Get file extension from path
  String _getFileExtension(String path) {
    try {
      final extension = path.split('.').last.toLowerCase();
      return supportedImageFormats.contains(extension) ? extension : 'jpg';
    } catch (e) {
      return 'jpg'; // default fallback
    }
  }

  // Get file extension from File object
  String _getFileExtensionFromFile(File file) {
    return _getFileExtension(file.path);
  }

  // Get current profile image path for a user
  Future<String?> getCurrentProfileImagePath(String uid) async {
    try {
      final user = await getUser(uid);
      return user?['profile_image'] as String?;
    } catch (e) {
      print('❌ Failed to get current profile image path: $e');
      return null;
    }
  }

  // Upload profile image and delete old one
  Future<String> uploadProfileImage(String uid, File imageFile) async {
    String? oldImagePath;

    try {
      print('🖼 Starting profile image upload for user: $uid');

      // Validate the image file first
      await _validateImageFile(imageFile);

      // Get current profile image path before uploading new one
      oldImagePath = await getCurrentProfileImagePath(uid);
      if (oldImagePath != null && oldImagePath.isNotEmpty) {
        print('📁 Current profile image path: $oldImagePath');
      }

      // Get file extension and create new filename
      final fileExtension = _getFileExtensionFromFile(imageFile);
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'profile_$timestamp.$fileExtension';
      final path = 'profiles/$uid/$fileName';

      print('📁 Uploading to new path: $path (format: $fileExtension)');

      // Upload new image
      final result =
          await uploadFileWithOverwrite('profile-images', path, imageFile);

      print('✅ Profile image uploaded successfully: $result');

      // Delete old image if exists and is different from new one
      if (oldImagePath != null &&
          oldImagePath.isNotEmpty &&
          oldImagePath != path) {
        await _deleteOldProfileImage(oldImagePath);
      }

      return path;
    } catch (e) {
      print('❌ Failed to upload profile image: $e');

      // Cleanup: If new image was uploaded but something else failed,
      // delete the new image to avoid orphaned files
      if (oldImagePath == null || oldImagePath.isEmpty) {
        print('🔄 No old image to restore, keeping new upload');
      }

      throw Exception('Failed to upload profile image: ${e.toString()}');
    }
  }

  // Delete old profile image
  Future<void> _deleteOldProfileImage(String oldImagePath) async {
    try {
      print('🗑 Attempting to delete old profile image: $oldImagePath');

      // Remove any bucket prefix that might be in the path
      String cleanPath = oldImagePath;
      if (cleanPath.startsWith('profile-images/')) {
        cleanPath = cleanPath.replaceFirst('profile-images/', '');
      }

      // Check if file exists before deleting
      final exists = await fileExists('profile-images', cleanPath);
      if (exists) {
        await deleteFile('profile-images', cleanPath);
        print('✅ Old profile image deleted successfully: $cleanPath');
      } else {
        print('ℹ Old profile image not found, skipping deletion: $cleanPath');
      }
    } catch (e) {
      // Log error but don't throw - we don't want to fail the whole operation
      // if deleting old image fails
      print('⚠ Failed to delete old profile image (non-critical): $e');
    }
  }

  // Update user profile with image and handle old image deletion
  Future<void> updateUserProfileWithImage({
    required String uid,
    required String fullName,
    required String username,
    required String phoneNumber,
    File? newProfileImage,
  }) async {
    String? newProfileImagePath;
    String? oldProfileImagePath;

    try {
      print('👤 Updating user profile for: $uid');

      // Get current profile image path before any changes
      oldProfileImagePath = await getCurrentProfileImagePath(uid);

      // Upload new image if provided
      if (newProfileImage != null) {
        newProfileImagePath = await uploadProfileImage(uid, newProfileImage);
      }

      final updateData = {
        'full_name': fullName,
        'username': username,
        'phone_number': phoneNumber,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
        if (newProfileImagePath != null) 'profile_image': newProfileImagePath,
      };

      await updateUser(uid, updateData);
      print('✅ User profile updated successfully');

      // Delete old image only after successful update
      if (newProfileImage != null &&
          oldProfileImagePath != null &&
          oldProfileImagePath.isNotEmpty &&
          newProfileImagePath != oldProfileImagePath) {
        await _deleteOldProfileImage(oldProfileImagePath);
      }
    } catch (e) {
      print('❌ Failed to update user profile: $e');

      // If update failed but new image was uploaded, try to clean up
      if (newProfileImagePath != null) {
        print(
            '🔄 Cleaning up newly uploaded image due to failure: $newProfileImagePath');
        try {
          await deleteFile('profile-images', newProfileImagePath);
        } catch (cleanupError) {
          print('⚠ Failed to cleanup new image: $cleanupError');
        }
      }

      throw Exception('Failed to update user profile: $e');
    }
  }

  // PERBAIKAN UTAMA: Get user profile with image URL - TAMBAHKAN AWAIT
  Future<Map<String, dynamic>?> getUserProfile(String uid) async {
    try {
      final userData = await getUser(uid);
      if (userData == null) return null;

      // Add profile image URL if exists - INI PERBAIKAN UTAMA
      if (userData['profile_image'] != null &&
          userData['profile_image'].isNotEmpty) {
        // TAMBAHKAN AWAIT di sini karena getPublicUrl sekarang synchronous
        userData['profile_image_url'] =
            getPublicUrl('profile-images', userData['profile_image']);
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

  // Clean up orphaned profile images (optional - for maintenance)
  Future<void> cleanupOrphanedProfileImages() async {
    try {
      // Get all profile images from storage
      final allImages = await client.storage.from('profile-images').list();

      // Get all users with profile images from database
      final users = await client.from('users').select('profile_image');

      final usedImagePaths = users
          .where((user) => user['profile_image'] != null)
          .map((user) => user['profile_image'] as String)
          .toSet();

      // Find orphaned images (in storage but not in database)
      final orphanedImages = allImages
          .where((image) => !usedImagePaths.contains(image.name))
          .toList();

      // Delete orphaned images
      for (final image in orphanedImages) {
        print('🗑 Deleting orphaned image: ${image.name}');
        await deleteFile('profile-images', image.name);
      }

      print(
          '✅ Cleanup completed. Deleted ${orphanedImages.length} orphaned images');
    } catch (e) {
      print('❌ Failed to cleanup orphaned images: $e');
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
      final String userId = progressData['user_id'];
      final int learningId = progressData['learning_id'];

      // Check if progress already exists
      final existingProgress = await client
          .from('learning_progress')
          .select()
          .eq('user_id', userId)
          .eq('learning_id', learningId)
          .maybeSingle();

      if (existingProgress != null) {
        // Update existing progress
        await client
            .from('learning_progress')
            .update(progressData)
            .eq('user_id', userId)
            .eq('learning_id', learningId);
      } else {
        // Insert new progress
        await client.from('learning_progress').insert(progressData);
      }
    } catch (e) {
      print('❌ Failed to update progress: $e');
      throw Exception('Failed to update progress: $e');
    }
  }

  // Get user progress
  Future<List<Map<String, dynamic>>> getUserProgress(String userId) async {
    try {
      final response = await client.from('progress').select('''
            *,
            lessons (*),
            learns (*)
          ''').eq('userId', userId);
      return response;
    } catch (e) {
      print('❌ Failed to get user progress: $e');
      throw Exception('Failed to get user progress: $e');
    }
  }

  Future<Map<String, dynamic>?> getLearningWithLessons(int learningId) async {
    try {
      final response = await client.from('learnings').select('''
          *,
          lessons:lessons(*)
        ''').eq('id', learningId).single();

      return response;
    } catch (e) {
      print('❌ Failed to get learning with lessons: $e');
      throw Exception('Failed to get learning with lessons: $e');
    }
  }

// Get user learning progress
  Future<Map<String, dynamic>?> getUserLearningProgress(
      String userId, int learningId) async {
    try {
      final response = await client
          .from('learning_progress')
          .select()
          .eq('user_id', userId)
          .eq('learning_id', learningId)
          .maybeSingle();

      return response;
    } catch (e) {
      print('❌ Failed to get user learning progress: $e');
      throw Exception('Failed to get user learning progress: $e');
    }
  }

  // Get learnings with user progress
  Future<List<Map<String, dynamic>>> getLearningsWithProgress(
      String userId) async {
    try {
      final response = await client
          .from('learnings')
          .select('''
          *,
          lessons:lessons(*),
          progress:learning_progress!left(
            progress_percentage,
            completed_lessons,
            updated_at
          )
        ''')
          .eq('learning_progress.user_id', userId)
          .order('created_at', ascending: false);

      return response;
    } catch (e) {
      print('❌ Failed to get learnings with progress: $e');
      // Fallback to basic learnings query if the complex one fails
      try {
        final response = await client.from('learnings').select('''
            *,
            lessons:lessons(*)
          ''').order('created_at', ascending: false);

        return response;
      } catch (fallbackError) {
        print('❌ Fallback query also failed: $fallbackError');
        throw Exception('Failed to get learnings: $e');
      }
    }
  }

// Get all learnings (without progress)
  Future<List<Map<String, dynamic>>> getAllLearnings() async {
    try {
      final response = await client.from('learnings').select('''
          *,
          lessons:lessons(*)
        ''').order('created_at', ascending: false);

      return response;
    } catch (e) {
      print('❌ Failed to get all learnings: $e');
      throw Exception('Failed to get learnings: $e');
    }
  }

// Toggle lesson completion status
  Future<void> toggleLessonCompletion({
    required String userId,
    required int learningId,
    required int lessonId,
    required bool isCompleted,
  }) async {
    try {
      // Get current progress
      final currentProgress = await getUserLearningProgress(userId, learningId);

      List<dynamic> completedLessons = [];
      if (currentProgress != null &&
          currentProgress['completed_lessons'] != null) {
        completedLessons =
            List.from(currentProgress['completed_lessons'] as List);
      }

      if (isCompleted) {
        // Add lesson to completed list if not already there
        if (!completedLessons.contains(lessonId)) {
          completedLessons.add(lessonId);
        }
      } else {
        // Remove lesson from completed list
        completedLessons.remove(lessonId);
      }

      // Calculate progress percentage
      final learning = await getLearningWithLessons(learningId);
      final totalLessons = learning?['lessons'] != null
          ? (learning!['lessons'] as List).length
          : 0;

      final progressPercentage = totalLessons > 0
          ? (completedLessons.length / totalLessons) * 100
          : 0.0;

      // Prepare progress data
      final progressData = {
        'user_id': userId,
        'learning_id': learningId,
        'completed_lessons': completedLessons,
        'progress_percentage': progressPercentage,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };

      // Use the fixed updateProgress method
      await updateProgress(progressData);

      print('✅ Lesson completion toggled successfully');
    } catch (e) {
      print('❌ Failed to toggle lesson completion: $e');
      throw Exception('Failed to toggle lesson completion: $e');
    }
  }

// Mark lesson as completed
  Future<void> markLessonAsCompleted({
    required String userId,
    required int learningId,
    required int lessonId,
  }) async {
    await toggleLessonCompletion(
      userId: userId,
      learningId: learningId,
      lessonId: lessonId,
      isCompleted: true,
    );
  }

// Mark lesson as uncompleted
  Future<void> markLessonAsUncompleted({
    required String userId,
    required int learningId,
    required int lessonId,
  }) async {
    await toggleLessonCompletion(
      userId: userId,
      learningId: learningId,
      lessonId: lessonId,
      isCompleted: false,
    );
  }

// Add this method to your SupabaseService class
  Future<void> updateLearningProgress({
    required String userId,
    required int learningId,
    required List<int> completedLessons,
    required double progressPercentage,
  }) async {
    try {
      await client.from('learning_progress').upsert({
        'user_id': userId,
        'learning_id': learningId,
        'completed_lessons': completedLessons,
        'progress_percentage': progressPercentage,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'user_id,learning_id');

      print('✅ Learning progress updated successfully');
    } catch (e) {
      print('❌ Failed to update learning progress: $e');
      throw Exception('Failed to update learning progress: $e');
    }
  }
}
