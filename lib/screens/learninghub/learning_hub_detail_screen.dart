import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LearningHubDetailScreen extends StatefulWidget {
  final String learningId;
  final String courseTitle;
  final String courseDescription;
  final double progress;
  final Map<String, dynamic> rawData;

  const LearningHubDetailScreen({
    super.key,
    required this.learningId,
    required this.courseTitle,
    required this.courseDescription,
    required this.progress,
    required this.rawData,
  });

  @override
  State<LearningHubDetailScreen> createState() => _LearningHubDetailScreenState();
}

class _LearningHubDetailScreenState extends State<LearningHubDetailScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String _formatCreatedAt(dynamic rawCreatedAt) {
    try {
      if (rawCreatedAt == null) return 'Unknown date';
      if (rawCreatedAt is Timestamp) {
        final dt = rawCreatedAt.toDate();
        return '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      }
      if (rawCreatedAt is int) {
        final dt = DateTime.fromMillisecondsSinceEpoch(rawCreatedAt);
        return '${dt.day}/${dt.month}/${dt.year}';
      }
      if (rawCreatedAt is String) return rawCreatedAt;
      if (rawCreatedAt is DateTime) {
        final dt = rawCreatedAt;
        return '${dt.day}/${dt.month}/${dt.year}';
      }
      return rawCreatedAt.toString();
    } catch (e) {
      return 'Unknown date';
    }
  }

  Future<void> _openUrl(BuildContext context, String url) async {
    try {
      final uri = Uri.parse(url);
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open the link')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Invalid URL: $e')),
      );
    }
  }

  // Toggle completed state for current user for lesson index `idx`
  Future<void> _toggleCompleted(int idx, bool currentlyCompleted, int totalLessons) async {
    final user = _auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to track progress')),
      );
      return;
    }

    final userProgRef = _firestore
        .collection('learnings')
        .doc(widget.learningId)
        .collection('userProgress')
        .doc(user.uid);

    try {
      if (currentlyCompleted) {
        // remove index
        await userProgRef.set({
          'completedLessons': FieldValue.arrayRemove([idx]),
          'updatedAt': FieldValue.serverTimestamp(),
          'userId': user.uid,
        }, SetOptions(merge: true));
      } else {
        // add index
        await userProgRef.set({
          'completedLessons': FieldValue.arrayUnion([idx]),
          'updatedAt': FieldValue.serverTimestamp(),
          'userId': user.uid,
        }, SetOptions(merge: true));
      }

      // Update the main learning document progress (only if user is the creator)
      try {
        final learningDoc = await _firestore.collection('learnings').doc(widget.learningId).get();
        if (learningDoc.exists && learningDoc.data()?['createdBy'] == user.uid) {
          final completedLessonsRef = await userProgRef.get();
          final completedLessonsList = completedLessonsRef.data()?['completedLessons'] as List?;
          final completedLessons = completedLessonsList?.length ?? 0;
          final newProgress = totalLessons > 0 ? completedLessons / totalLessons : 0.0;
          
          await _firestore.collection('learnings').doc(widget.learningId).update({
            'progress': newProgress,
          });
        }
      } catch (e) {
        // Silently fail if user doesn't have permission to update the main document
        print('User not authorized to update main progress: $e');
      }

      // success feedback
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(currentlyCompleted ? 'Marked as not completed' : 'Marked as completed')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update progress: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final Color scaffoldBackground = Theme.of(context).scaffoldBackgroundColor;
    final Color cardColor = Theme.of(context).cardColor;
    final Color textColor = Theme.of(context).colorScheme.onBackground;
    final Color dividerColor = isDarkMode ? Colors.grey[700]! : Colors.grey[300]!;
    final Color hintColor = isDarkMode ? Colors.grey[400]! : Colors.grey[600]!;

    final coverImage = (widget.rawData['coverImageUrl'] as String?) ??
        'https://cdn-icons-png.flaticon.com/512/888/888883.png';
    final createdAt = _formatCreatedAt(widget.rawData['createdAt']);
    final lessonsRaw = widget.rawData['lessons'];
    List<Map<String, dynamic>> lessons = [];

    if (lessonsRaw is List) {
      for (final item in lessonsRaw) {
        if (item is Map<String, dynamic>) {
          lessons.add(item);
        } else if (item is Map) {
          lessons.add(Map<String, dynamic>.from(item));
        }
      }
    }

    final totalLessons = lessons.length;

    final user = _auth.currentUser;
    final userProgressStream = (user != null)
        ? _firestore
            .collection('learnings')
            .doc(widget.learningId)
            .collection('userProgress')
            .doc(user.uid)
            .snapshots()
        : const Stream.empty();

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
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: userProgressStream as Stream<DocumentSnapshot<Map<String, dynamic>>>?,
        builder: (context, snap) {
          Set<int> completedIndexes = {};
          if (snap.hasData && snap.data!.exists) {
            final data = snap.data!.data();
            final completed = (data?['completedLessons']);
            if (completed is List) {
              for (final item in completed) {
                try {
                  completedIndexes.add(int.parse(item.toString()));
                } catch (_) {
                  // ignore non-int values
                }
              }
            }
          }

          final completedCount = completedIndexes.length;
          final userProgress = totalLessons > 0 ? (completedCount / totalLessons) : 0.0;

          String overallStatus = 'Not Started';
          Color statusColor = Colors.grey;
          
          if (completedCount > 0 && completedCount < totalLessons) {
            overallStatus = 'In Progress';
            statusColor = Colors.blue;
          } else if (completedCount == totalLessons && totalLessons > 0) {
            overallStatus = 'Completed';
            statusColor = Colors.green;
          }

          return Column(
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
                          coverImage,
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
                      if (lessons.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 20.0),
                          child: Text(
                            'No lessons found for this course.',
                            style: TextStyle(color: hintColor),
                          ),
                        )
                      else
                        Column(
                          children: lessons.asMap().entries.map((entry) {
                            final idx = entry.key;
                            final lesson = entry.value;
                            final lessonTitle = (lesson['title'] as String?) ?? 'Lesson ${idx + 1}';
                            final lessonDesc = (lesson['description'] as String?) ?? '';
                            final contentType = (lesson['contentType'] as String?) ?? '';
                            final contentUrl = (lesson['contentUrl'] as String?) ?? '';
                            final completed = completedIndexes.contains(idx);

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
                                      if (contentUrl.isNotEmpty)
                                        ElevatedButton.icon(
                                          onPressed: () => _openUrl(context, contentUrl),
                                          icon: const Icon(Icons.open_in_new, size: 16, color: Colors.white),
                                          label: const Text('Open', style: TextStyle(color: Colors.white)),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color.fromRGBO(224, 124, 124, 1),
                                            elevation: 0,
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                          ),
                                        ),
                                      if (contentUrl.isEmpty)
                                        Text(
                                          'No content URL',
                                          style: TextStyle(color: hintColor, fontSize: 13),
                                        ),
                                      const Spacer(),
                                      if (user != null)
                                        IconButton(
                                          onPressed: () => _toggleCompleted(idx, completed, totalLessons),
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
                              value: user != null ? userProgress.clamp(0.0, 1.0) : widget.progress.clamp(0.0, 1.0),
                              backgroundColor: isDarkMode ? Colors.grey[700] : Colors.grey[300],
                              valueColor: AlwaysStoppedAnimation<Color>(
                                userProgress >= 1.0 ? Colors.green : Colors.blue,
                              ),
                              minHeight: 12.0,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16.0),
                        Text(
                          '${((user != null ? userProgress : widget.progress) * 100).toInt()}%',
                          style: TextStyle(
                            fontSize: 18.0,
                            fontWeight: FontWeight.bold,
                            color: userProgress >= 1.0
                                ? Colors.green
                                : userProgress > 0.0
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
          );
        },
      ),
    );
  }
}