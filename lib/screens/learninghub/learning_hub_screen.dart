import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'learning_hub_create_screen.dart';
import 'learning_hub_detail_screen.dart';
import 'learning_hub_complete_screen.dart';
import 'learning_hub_in_progress_screen.dart';
import 'learning_hub_all_screen.dart';

class LearningHubScreen extends StatefulWidget {
  const LearningHubScreen({super.key});

  @override
  State<LearningHubScreen> createState() => _LearningHubScreenState();
}

class _LearningHubScreenState extends State<LearningHubScreen> with WidgetsBindingObserver {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _shouldRefresh = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      setState(() {
        _shouldRefresh = true;
      });
    }
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text;
    });
  }

  Future<void> _refreshData() async {
    setState(() {
      _shouldRefresh = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final Color appBarIconColor = isDarkMode ? Colors.white : Colors.black;
    final Color scaffoldBackground = Theme.of(context).scaffoldBackgroundColor;
    final Color cardColor = Theme.of(context).cardColor;
    final Color textColor = Theme.of(context).colorScheme.onBackground;
    final Color hintColor = isDarkMode ? Colors.grey[400]! : Colors.grey[600]!;
    final Color searchBackground = isDarkMode ? Colors.grey[800]! : Colors.grey[200]!;

    return Focus(
      onFocusChange: (hasFocus) {
        if (hasFocus && _shouldRefresh) {
          _refreshData();
        }
      },
      child: Scaffold(
        backgroundColor: scaffoldBackground,
        appBar: AppBar(
          title: Text(
            'Learning Hub',
            style: TextStyle(color: textColor),
          ),
          centerTitle: true,
          elevation: 0,
          backgroundColor: Colors.transparent,
          foregroundColor: appBarIconColor,
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
        floatingActionButton: FloatingActionButton(
          backgroundColor: const Color.fromRGBO(224, 124, 124, 1),
          foregroundColor: Colors.white,
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const LearningHubCreateScreen()),
            ).then((newLearning) {
              if (newLearning != null &&
                  newLearning is Map &&
                  newLearning['id'] != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Learning created (id: ${newLearning['id']})')),
                );
                setState(() {
                  _shouldRefresh = true;
                });
              }
            });
          },
          child: const Icon(Icons.add),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Container(
                decoration: BoxDecoration(
                  color: searchBackground,
                  borderRadius: BorderRadius.circular(12.0),
                ),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search Now...',
                    hintStyle: TextStyle(color: hintColor),
                    prefixIcon: Icon(Icons.search, color: hintColor),
                    border: InputBorder.none,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
                  ),
                  style: TextStyle(color: textColor),
                ),
              ),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('learnings')
                    .orderBy('createdAt', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                      child: Text('Error loading learnings: ${snapshot.error}'),
                    );
                  }
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final docs = snapshot.data?.docs ?? [];
                  List<Map<String, dynamic>> allCourses = docs.map((d) {
                    final data = d.data();
                    return {
                      'id': d.id,
                      'title': data['title'] ?? 'Untitled',
                      'description': data['description'] ?? '',
                      'imageUrl': data['coverImageUrl'],
                      'raw': data,
                    };
                  }).toList();

                  final query = _searchQuery.trim().toLowerCase();
                  List<Map<String, dynamic>> filtered = allCourses;
                  if (query.isNotEmpty) {
                    filtered = allCourses.where((course) {
                      final title = course['title'].toLowerCase();
                      final description = course['description'].toLowerCase();
                      return title.contains(query) || description.contains(query);
                    }).toList();
                  }

                  final user = FirebaseAuth.instance.currentUser;
                  if (user == null) {
                    final allCoursesFiltered = filtered.map((course) {
                      return {
                        ...course,
                        'progress': 0.0,
                        'category': 'notstarted',
                      };
                    }).toList();
                    return _buildListUI(context, allCoursesFiltered, [], [], filtered.isEmpty, isDarkMode);
                  } else {
                    final userProgFutures = filtered.map((course) {
                      return FirebaseFirestore.instance
                          .collection('learnings')
                          .doc(course['id'])
                          .collection('userProgress')
                          .doc(user.uid)
                          .get();
                    }).toList();

                    return FutureBuilder<List<DocumentSnapshot<Map<String, dynamic>>>>(
                      future: Future.wait(userProgFutures),
                      builder: (context, progSnapshot) {
                        if (progSnapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        if (progSnapshot.hasError) {
                          final allCoursesFiltered = filtered.map((course) {
                            return {
                              ...course,
                              'progress': 0.0,
                              'category': 'notstarted',
                            };
                          }).toList();
                          return _buildListUI(context, allCoursesFiltered, [], [], filtered.isEmpty, isDarkMode);
                        }

                        final progDocs = progSnapshot.data ?? [];
                        List<Map<String, dynamic>> combined = [];
                        for (int i = 0; i < filtered.length; i++) {
                          final course = filtered[i];
                          final raw = course['raw'];
                          final progDoc = progDocs[i];
                          double displayProgress = 0.0;

                          if (progDoc.exists) {
                            final data = progDoc.data() ?? {};
                            final completed = data['completedLessons'];
                            int completedCount = 0;
                            if (completed is List) completedCount = completed.length;
                            else if (completed is int) completedCount = completed;

                            int totalLessons = 0;
                            if (raw['lessons'] is List) totalLessons = (raw['lessons'] as List).length;

                            if (totalLessons > 0) {
                              displayProgress = (completedCount / totalLessons).clamp(0.0, 1.0);
                            }
                          }

                          String category;
                          if (displayProgress >= 1.0) category = 'complete';
                          else if (displayProgress > 0.0) category = 'inprogress';
                          else category = 'notstarted';

                          combined.add({
                            ...course,
                            'progress': displayProgress,
                            'category': category,
                          });
                        }

                        final completeCourses = combined.where((c) => c['category'] == 'complete').toList();
                        final inProgressCourses = combined.where((c) => c['category'] == 'inprogress').toList();
                        return _buildListUI(context, combined, completeCourses, inProgressCourses, combined.isEmpty, isDarkMode);
                      },
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListUI(BuildContext context, List<Map<String, dynamic>> allCoursesFiltered,
      List<Map<String, dynamic>> completeCourses, List<Map<String, dynamic>> inProgressCourses, bool isEmpty, bool isDarkMode) {
    final Color textColor = Theme.of(context).colorScheme.onBackground;
    final Color cardColor = Theme.of(context).cardColor;

    return SingleChildScrollView(
      padding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (completeCourses.isNotEmpty) ...[
            _buildSectionHeader('Complete', completeCourses.length > 2, () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const LearningHubCompleteScreen()),
              ).then((_) {
                setState(() {
                  _shouldRefresh = true;
                });
              });
            }, textColor),
            const SizedBox(height: 12.0),
            ...completeCourses.take(2).map((course) => _learningItemCardFromMap(course, cardColor, textColor)),
            const SizedBox(height: 24.0),
          ],
          if (inProgressCourses.isNotEmpty) ...[
            _buildSectionHeader('In progress', inProgressCourses.length > 2, () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const LearningHubInprogressScreen()),
              ).then((_) {
                setState(() {
                  _shouldRefresh = true;
                });
              });
            }, textColor),
            const SizedBox(height: 12.0),
            ...inProgressCourses.take(2).map((course) => _learningItemCardFromMap(course, cardColor, textColor)),
            const SizedBox(height: 24.0),
          ],
          if (allCoursesFiltered.isNotEmpty) ...[
            _buildSectionHeader('All learning', allCoursesFiltered.length > 2, () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const LearningHubAllScreen()),
              ).then((_) {
                setState(() {
                  _shouldRefresh = true;
                });
              });
            }, textColor),
            const SizedBox(height: 12.0),
            ...allCoursesFiltered.take(2).map((course) => _learningItemCardFromMap(course, cardColor, textColor)),
          ],
          if (isEmpty) Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 40.0),
              child: Text(
                'No courses found',
                style: TextStyle(fontSize: 18.0, color: Colors.grey),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, bool showSeeAll, VoidCallback onSeeAllPressed, Color textColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: TextStyle(fontSize: 20.0, fontWeight: FontWeight.bold, color: textColor),
        ),
        if (showSeeAll) TextButton(
          onPressed: onSeeAllPressed,
          child: const Text(
            'See All',
            style: TextStyle(color: Color.fromRGBO(224, 124, 124, 1), fontSize: 16.0, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  Widget _learningItemCardFromMap(Map<String, dynamic> course, Color cardColor, Color textColor) {
    final title = course['title'];
    final subtitle = course['description'];
    final imageUrl = course['imageUrl'];
    final progress = course['progress'] ?? 0.0;
    final raw = course['raw'];
    final learningId = course['id'];

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => LearningHubDetailScreen(
              learningId: learningId,
              courseTitle: title,
              courseDescription: subtitle,
              progress: progress,
              rawData: raw,
            ),
          ),
        ).then((_) {
          setState(() {
            _shouldRefresh = true;
          });
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8.0),
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(12.0),
          boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.3), spreadRadius: 1, blurRadius: 6, offset: const Offset(0, 3))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8.0),
                  child: Image.network(
                    imageUrl,
                    width: 60,
                    height: 60,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      width: 60,
                      height: 60,
                      color: Colors.grey[100],
                      alignment: Alignment.center,
                      child: const Icon(Icons.description, color: Colors.grey),
                    ),
                  ),
                ),
                const SizedBox(width: 16.0),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18.0, color: textColor)),
                      const SizedBox(height: 6.0),
                      Text(subtitle, style: TextStyle(color: Colors.grey[600], fontSize: 14.0)),
                    ],
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
                      value: progress.clamp(0.0, 1.0),
                      backgroundColor: Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation<Color>(
                        progress >= 1.0 ? Colors.green : Colors.blue,
                      ),
                      minHeight: 10.0,
                    ),
                  ),
                ),
                const SizedBox(width: 12.0),
                Text(
                  '${(progress * 100).toInt()}%',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: progress >= 1.0 ? Colors.green : progress > 0.0 ? Colors.blue : Colors.grey,
                    fontSize: 14.0,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}