import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:onboardx_tnb_app/services/supabase_service.dart';

class LessonItemWidget extends StatefulWidget {
  final Map<String, dynamic> lesson;
  final int learningId;
  final VoidCallback? onProgressUpdate;

  const LessonItemWidget({
    Key? key,
    required this.lesson,
    required this.learningId,
    this.onProgressUpdate,
  }) : super(key: key);

  @override
  State<LessonItemWidget> createState() => _LessonItemWidgetState();
}

class _LessonItemWidgetState extends State<LessonItemWidget> {
  final SupabaseService _supabaseService = SupabaseService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  bool _isLoading = false;
  bool _isCompleted = false;

  @override
  void initState() {
    super.initState();
    _checkLessonCompletion();
  }

  Future<void> _checkLessonCompletion() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final progress = await _supabaseService.getUserLearningProgress(
        user.uid, 
        widget.learningId
      );

      if (progress != null && progress['completed_lessons'] != null) {
        final completedLessons = List.from(progress['completed_lessons'] as List);
        setState(() {
          _isCompleted = completedLessons.contains(widget.lesson['id']);
        });
      }
    } catch (e) {
      print('Error checking lesson completion: $e');
    }
  }

  Future<void> _toggleCompletion() async {
    if (_isLoading) return;

    final user = _auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be signed in')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      if (_isCompleted) {
        // Untick - mark as uncompleted
        await _supabaseService.markLessonAsUncompleted(
          userId: user.uid,
          learningId: widget.learningId,
          lessonId: widget.lesson['id'],
        );
        setState(() {
          _isCompleted = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lesson marked as not completed')),
        );
      } else {
        // Tick - mark as completed
        await _supabaseService.markLessonAsCompleted(
          userId: user.uid,
          learningId: widget.learningId,
          lessonId: widget.lesson['id'],
        );
        setState(() {
          _isCompleted = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lesson marked as completed!')),
        );
      }

      // Notify parent widget about progress update
      widget.onProgressUpdate?.call();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update progress: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final Color cardColor = Theme.of(context).cardColor;
    final Color textColor = Theme.of(context).colorScheme.onBackground;

    return Card(
      color: cardColor,
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: ListTile(
        leading: _isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : IconButton(
                icon: Icon(
                  _isCompleted ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: _isCompleted ? Colors.green : Colors.grey,
                ),
                onPressed: _toggleCompletion,
              ),
        title: Text(
          widget.lesson['title'] ?? 'Untitled Lesson',
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: widget.lesson['description'] != null
            ? Text(
                widget.lesson['description'],
                style: TextStyle(
                  color: textColor.withOpacity(0.7),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              )
            : null,
        trailing: Icon(
          _getContentTypeIcon(widget.lesson['content_type']),
          color: Colors.grey,
        ),
      ),
    );
  }

  IconData _getContentTypeIcon(String contentType) {
    switch (contentType.toLowerCase()) {
      case 'video':
        return Icons.videocam;
      case 'document':
        return Icons.description;
      default:
        return Icons.article;
    }
  }
}