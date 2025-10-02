import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:onboardx_tnb_app/services/supabase_service.dart';

import 'learning_hub_detail_screen.dart';

class LearningHubCompleteScreen extends StatefulWidget {
  const LearningHubCompleteScreen({super.key});

  @override
  State<LearningHubCompleteScreen> createState() => _LearningHubCompleteScreenState();
}

class _LearningHubCompleteScreenState extends State<LearningHubCompleteScreen> with WidgetsBindingObserver {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  List<Map<String, dynamic>> _completeCourses = [];
  bool _isLoading = true;

  final SupabaseService _supabaseService = SupabaseService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    WidgetsBinding.instance.addObserver(this);
    _loadLearnings();
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
      _loadLearnings();
    }
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text;
    });
  }

  Future<void> _loadLearnings() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final user = _auth.currentUser;
      List<Map<String, dynamic>> learnings = [];

      if (user != null) {
        // Load learnings with user progress
        learnings = await _supabaseService.getLearningsWithProgress(user.uid);
      } else {
        // Load all learnings without progress
        final response = await _supabaseService.client
            .from('learnings')
            .select('''
            *,
            lessons:lessons(*)
          ''')
            .order('created_at', ascending: false);

        learnings = List<Map<String, dynamic>>.from(response);
      }

      // Process learnings data dan filter hanya complete
      List<Map<String, dynamic>> processedCourses = [];
      
      for (final learning in learnings) {
        final coverImagePath = learning['cover_image_path'] as String?;
        String imageUrl = 'https://cdn-icons-png.flaticon.com/512/888/888883.png';
        
        if (coverImagePath != null && coverImagePath.isNotEmpty) {
          imageUrl = _supabaseService.getPublicUrl('learning-content', coverImagePath);
        }

        double progress = 0.0;

        if (user != null) {
          // Calculate progress from learning_progress
          final progressData = learning['progress'] as List?;
          if (progressData != null && progressData.isNotEmpty) {
            final progressItem = progressData.first as Map<String, dynamic>;
            progress = (progressItem['progress_percentage'] as num?)?.toDouble() ?? 0.0;
          }
        }

        // Hanya tambahkan course yang complete (progress >= 1.0)
        if (progress >= 1.0) {
          processedCourses.add({
            'id': learning['id'],
            'title': learning['title'] ?? 'Untitled',
            'description': learning['description'] ?? '',
            'imageUrl': imageUrl,
            'progress': progress,
            'raw': learning,
            'total_lessons': learning['total_lessons'] ?? 0,
          });
        }
      }

      setState(() {
        _completeCourses = processedCourses;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading learnings: $e');
      setState(() {
        _isLoading = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading learnings: $e')),
      );
    }
  }

  List<Map<String, dynamic>> _getFilteredCourses() {
    if (_searchQuery.isEmpty) {
      return _completeCourses;
    }

    final query = _searchQuery.trim().toLowerCase();
    return _completeCourses.where((course) {
      final title = course['title'].toString().toLowerCase();
      final description = course['description'].toString().toLowerCase();
      return title.contains(query) || description.contains(query);
    }).toList();
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

    final filteredCourses = _getFilteredCourses();

    return Scaffold(
      backgroundColor: scaffoldBackground,
      appBar: AppBar(
        title: Text(
          'Complete',
          style: TextStyle(color: textColor),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: appBarIconColor,
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
                  hintText: 'Search Complete...',
                  hintStyle: TextStyle(color: hintColor),
                  prefixIcon: Icon(Icons.search, color: hintColor),
                  border: InputBorder.none,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
                ),
                style: TextStyle(color: textColor),
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _loadLearnings,
                    child: filteredCourses.isEmpty
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 40.0),
                              child: Text(
                                'No completed courses found',
                                style: TextStyle(fontSize: 18.0, color: Colors.grey),
                              ),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 16.0),
                            itemCount: filteredCourses.length,
                            itemBuilder: (context, index) {
                              return _learningItemCardFromMap(
                                filteredCourses[index], 
                                cardColor, 
                                textColor
                              );
                            },
                          ),
                  ),
          ),
        ],
      ),
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
              totalLessons: course['total_lessons'] ?? 0,
            ),
          ),
        ).then((_) {
          // Reload data setelah kembali dari detail screen untuk update progress
          _loadLearnings();
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12.0),
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(12.0),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.3), 
              spreadRadius: 1, 
              blurRadius: 6, 
              offset: const Offset(0, 3)
            ),
          ],
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
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        width: 60,
                        height: 60,
                        color: Colors.grey[200],
                        alignment: Alignment.center,
                        child: const CircularProgressIndicator(),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: 60,
                        height: 60,
                        color: Colors.grey[100],
                        alignment: Alignment.center,
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.broken_image, color: Colors.grey, size: 24),
                            Text(
                              'No Image',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 16.0),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title, 
                        style: TextStyle(
                          fontWeight: FontWeight.bold, 
                          fontSize: 18.0, 
                          color: textColor
                        ),
                      ),
                      const SizedBox(height: 6.0),
                      Text(
                        subtitle, 
                        style: TextStyle(
                          color: Colors.grey[600], 
                          fontSize: 14.0
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
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
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
                      minHeight: 10.0,
                    ),
                  ),
                ),
                const SizedBox(width: 12.0),
                Text(
                  '${(progress * 100).toInt()}%',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                    fontSize: 14.0,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8.0),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle, color: Colors.green[700], size: 16),
                  const SizedBox(width: 4),
                  Text(
                    'Completed',
                    style: TextStyle(
                      color: Colors.green[700],
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}