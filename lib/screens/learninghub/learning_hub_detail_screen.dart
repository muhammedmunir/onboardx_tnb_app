import 'package:flutter/material.dart';
import 'package:onboardx_tnb_app/screens/learninghub/document_viewer_screen.dart';
import 'package:onboardx_tnb_app/screens/learninghub/video_player_screen.dart';
import 'package:onboardx_tnb_app/services/supabase_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LearningHubDetailScreen extends StatefulWidget {
  final int learningId;
  final String courseTitle;
  final String courseDescription;
  final double progress;
  final Map<String, dynamic> rawData;
  final int totalLessons;

  const LearningHubDetailScreen({
    super.key,
    required this.learningId,
    required this.courseTitle,
    required this.courseDescription,
    required this.progress,
    required this.rawData,
    required this.totalLessons,
  });

  @override
  State<LearningHubDetailScreen> createState() => _LearningHubDetailScreenState();
}

class _LearningHubDetailScreenState extends State<LearningHubDetailScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final SupabaseService _supabaseService = SupabaseService();
  
  List<Map<String, dynamic>> _lessons = [];
  Set<int> _completedIndexes = {};
  double _userProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _loadLessons();
    _loadUserProgress();
  }

  String _formatCreatedAt(dynamic rawCreatedAt) {
    try {
      if (rawCreatedAt == null) return 'Unknown date';
      if (rawCreatedAt is String) {
        final dt = DateTime.parse(rawCreatedAt).toLocal();
        return '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      }
      if (rawCreatedAt is DateTime) {
        final dt = rawCreatedAt.toLocal();
        return '${dt.day}/${dt.month}/${dt.year}';
      }
      return rawCreatedAt.toString();
    } catch (e) {
      return 'Unknown date';
    }
  }

  Future<void> _loadLessons() async {
    try {
      final response = await _supabaseService.client
          .from('lessons')
          .select()
          .eq('learning_id', widget.learningId)
          .order('order_index');

      if (response != null) {
        setState(() {
          _lessons = List<Map<String, dynamic>>.from(response);
        });
      }
    } catch (e) {
      print('Error loading lessons: $e');
    }
  }

  Future<void> _loadUserProgress() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final response = await _supabaseService.client
          .from('learning_progress')
          .select()
          .eq('user_id', user.uid)
          .eq('learning_id', widget.learningId)
          .maybeSingle();

      if (response != null) {
        final completedLessons = response['completed_lessons'] as List?;
        setState(() {
          _completedIndexes = completedLessons != null 
              ? Set<int>.from(completedLessons.map((e) => int.parse(e.toString())))
              : <int>{};
          _userProgress = (response['progress_percentage'] as num?)?.toDouble() ?? 0.0;
        });
      }
    } catch (e) {
      print('Error loading user progress: $e');
    }
  }

  Future<void> _openContent(BuildContext context, String contentPath, String contentType) async {
  try {
    // Determine the correct bucket based on content type
    final bucket = contentType.toLowerCase().contains('video') ? 'videos' : 'documents';

    // Debug prints
    print('📂 Opening content:');
    print('  - Bucket: $bucket');
    print('  - Content Path: $contentPath');
    print('  - Content Type: $contentType');

    // Get public URL from Supabase storage
    final publicUrl = _supabaseService.getPublicUrl(bucket, contentPath);
    print('🔗 Final URL: $publicUrl');

    final lowerContentType = contentType.toLowerCase();

    // detect extension too (safer)
    final ext = contentPath.split('.').last.toLowerCase();

    if (lowerContentType.contains('video') || ext == 'mp4' || ext == 'mov' || ext == 'mkv') {
      // Navigate to video player
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => VideoPlayerScreen(
            videoUrl: publicUrl,
            videoTitle: 'Lesson Video',
          ),
        ),
      );
      return;
    }

    // If PDF -> use Google Docs viewer wrapper (works in WebView & browser)
    if (ext == 'pdf' || lowerContentType.contains('pdf')) {
      final encoded = Uri.encodeComponent(publicUrl);
      final gdocViewer = 'https://docs.google.com/gview?embedded=true&url=$encoded';

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => DocumentViewerScreen(
            documentUrl: gdocViewer,
            documentTitle: 'Lesson Document',
            contentType: 'pdf', // mark as pdf
          ),
        ),
      );
      return;
    }

    // Default: open in DocumentViewerScreen (for html, docx links etc.)
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DocumentViewerScreen(
          documentUrl: publicUrl,
          documentTitle: 'Lesson Document',
          contentType: contentType,
        ),
      ),
    );
  } catch (e) {
    print('❌ Error opening content: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error opening content: $e')),
    );
  }
}


  Future<void> _toggleCompleted(int idx, bool currentlyCompleted) async {
  final user = _auth.currentUser;
  if (user == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Please sign in to track progress')),
    );
    return;
  }

  try {
    Set<int> newCompletedIndexes = Set<int>.from(_completedIndexes);
    
    if (currentlyCompleted) {
      newCompletedIndexes.remove(idx);
    } else {
      newCompletedIndexes.add(idx);
    }

    final totalLessons = _lessons.length;
    final progressPercentage = totalLessons > 0 ? newCompletedIndexes.length / totalLessons : 0.0;

    // PERBAIKAN: Gunakan onConflict untuk handle duplicate key
    await _supabaseService.client
        .from('learning_progress')
        .upsert({
          'user_id': user.uid,
          'learning_id': widget.learningId,
          'completed_lessons': newCompletedIndexes.toList(),
          'progress_percentage': progressPercentage,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        }, onConflict: 'user_id,learning_id'); // TAMBAHKAN onConflict parameter

    setState(() {
      _completedIndexes = newCompletedIndexes;
      _userProgress = progressPercentage;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(currentlyCompleted ? 'Marked as not completed' : 'Marked as completed')),
    );
  } catch (e) {
    print('Error updating progress: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Failed to update progress: $e')),
    );
  }
}

  String _getCoverImageUrl() {
  final coverImagePath = widget.rawData['cover_image_path'] as String?;
  if (coverImagePath != null && coverImagePath.isNotEmpty) {
    // PERBAIKAN: Pastikan menggunakan bucket 'learning-content' dan path yang benar
    return _supabaseService.getPublicUrl('learning-content', coverImagePath);
  }
  return 'https://cdn-icons-png.flaticon.com/512/888/888883.png';
}

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final Color scaffoldBackground = Theme.of(context).scaffoldBackgroundColor;
    final Color cardColor = Theme.of(context).cardColor;
    final Color textColor = Theme.of(context).colorScheme.onBackground;
    final Color dividerColor = isDarkMode ? Colors.grey[700]! : Colors.grey[300]!;
    final Color hintColor = isDarkMode ? Colors.grey[400]! : Colors.grey[600]!;

    final coverImageUrl = _getCoverImageUrl();
    final createdAt = _formatCreatedAt(widget.rawData['created_at']);
    final totalLessons = _lessons.length;
    final completedCount = _completedIndexes.length;

    String overallStatus = 'Not Started';
    Color statusColor = Colors.grey;
    
    if (completedCount > 0 && completedCount < totalLessons) {
      overallStatus = 'In Progress';
      statusColor = Colors.blue;
    } else if (completedCount == totalLessons && totalLessons > 0) {
      overallStatus = 'Completed';
      statusColor = Colors.green;
    }

    return Scaffold(
      backgroundColor: scaffoldBackground,
      appBar: AppBar(
        title: Text(
          'Learning Overview',
          style: TextStyle(color: textColor),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: textColor,
        automaticallyImplyLeading: false,
        leading: Center(
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color.fromRGBO(224, 124, 124, 1),
                borderRadius: BorderRadius.circular(6),
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.arrow_back_ios_new,
                color: Colors.white,
                size: 16,
              ),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Cover image
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      coverImageUrl,
                      width: double.infinity,
                      height: 180,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          width: double.infinity,
                          height: 180,
                          color: Colors.grey[200],
                          alignment: Alignment.center,
                          child: const Icon(Icons.image_not_supported, size: 48, color: Colors.grey),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16.0),

                  // Title & meta
                  Text(
                    widget.courseTitle,
                    style: TextStyle(
                      fontSize: 24.0,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 8.0),
                  Text(
                    widget.courseDescription,
                    style: TextStyle(
                      fontSize: 16.0,
                      color: hintColor,
                    ),
                  ),
                  const SizedBox(height: 8.0),
                  
                  // Status badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: statusColor.withOpacity(0.3)),
                    ),
                    child: Text(
                      overallStatus,
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 8.0),
                  Row(
                    children: [
                      Icon(Icons.calendar_today, size: 14, color: hintColor),
                      const SizedBox(width: 6),
                      Text(
                        'Created: $createdAt',
                        style: TextStyle(fontSize: 13, color: hintColor),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24.0),

                  // Lessons header + user progress summary
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Lessons',
                        style: TextStyle(
                          fontSize: 20.0,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      Text(
                        '${completedCount}/${totalLessons} completed',
                        style: TextStyle(color: hintColor),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12.0),

                  // Lessons list
                  if (_lessons.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20.0),
                      child: Text(
                        'No lessons found for this course.',
                        style: TextStyle(color: hintColor),
                      ),
                    )
                  else
                    Column(
                      children: _lessons.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final lesson = entry.value;
                        final lessonTitle = (lesson['title'] as String?) ?? 'Lesson ${idx + 1}';
                        final lessonDesc = (lesson['description'] as String?) ?? '';
                        final contentType = (lesson['content_type'] as String?) ?? '';
                        final contentPath = (lesson['content_path'] as String?) ?? '';
                        final completed = _completedIndexes.contains(idx);

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12.0),
                          padding: const EdgeInsets.all(12.0),
                          decoration: BoxDecoration(
                            color: cardColor,
                            borderRadius: BorderRadius.circular(12.0),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withOpacity(isDarkMode ? 0.1 : 0.12),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      lessonTitle,
                                      style: TextStyle(
                                        fontSize: 16.0,
                                        fontWeight: FontWeight.w600,
                                        color: textColor,
                                      ),
                                    ),
                                  ),
                                  if (completed)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: Colors.green.withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(color: Colors.green.withOpacity(0.25)),
                                      ),
                                      child: const Text(
                                        'Completed',
                                        style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                ],
                              ),
                              if (lessonDesc.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text(
                                  lessonDesc,
                                  style: TextStyle(color: hintColor),
                                ),
                              ],
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  if (contentType.isNotEmpty)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                      margin: const EdgeInsets.only(right: 8),
                                      decoration: BoxDecoration(
                                        color: isDarkMode ? Colors.grey[800] : Colors.grey[100],
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        contentType,
                                        style: TextStyle(color: isDarkMode ? Colors.grey[300] : Colors.grey[700]),
                                      ),
                                    ),
                                  if (contentPath.isNotEmpty)
                                    ElevatedButton.icon(
                                      onPressed: () => _openContent(context, contentPath, contentType),
                                      icon: const Icon(Icons.open_in_new, size: 16, color: Colors.white),
                                      label: const Text('Open', style: TextStyle(color: Colors.white)),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color.fromRGBO(224, 124, 124, 1),
                                        elevation: 0,
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                      ),
                                    ),
                                  if (contentPath.isEmpty)
                                    Text(
                                      'No content available',
                                      style: TextStyle(color: hintColor, fontSize: 13),
                                    ),
                                  const Spacer(),
                                  IconButton(
                                    onPressed: () => _toggleCompleted(idx, completed),
                                    icon: Icon(
                                      completed ? Icons.check_circle : Icons.radio_button_unchecked,
                                      color: completed ? Colors.green : hintColor,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),

          // Progress Section (Fixed at the bottom)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20.0),
                topRight: Radius.circular(20.0),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(isDarkMode ? 0.3 : 0.2),
                  spreadRadius: 2,
                  blurRadius: 8,
                  offset: const Offset(0, -3),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Your Progress',
                      style: TextStyle(
                        fontSize: 16.0,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    Text(
                      overallStatus,
                      style: TextStyle(
                        fontSize: 14.0,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16.0),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: _userProgress.clamp(0.0, 1.0),
                          backgroundColor: isDarkMode ? Colors.grey[700] : Colors.grey[300],
                          valueColor: AlwaysStoppedAnimation<Color>(
                            _userProgress >= 1.0 ? Colors.green : Colors.blue,
                          ),
                          minHeight: 12.0,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16.0),
                    Text(
                      '${(_userProgress * 100).toInt()}%',
                      style: TextStyle(
                        fontSize: 18.0,
                        fontWeight: FontWeight.bold,
                        color: _userProgress >= 1.0
                            ? Colors.green
                            : _userProgress > 0.0
                                ? Colors.blue
                                : hintColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}