import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:onboardx_tnb_app/services/supabase_service.dart';

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
  List<Map<String, dynamic>> _allCourses = [];
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

    // Process learnings data
    List<Map<String, dynamic>> processedCourses = [];
    
    for (final learning in learnings) {
      final coverImagePath = learning['cover_image_path'] as String?;
      String imageUrl = 'https://cdn-icons-png.flaticon.com/512/888/888883.png';
      
      // DEBUG: Log cover image path
      print('🖼 Cover Image Path from DB: $coverImagePath');
      
      if (coverImagePath != null && coverImagePath.isNotEmpty) {
        imageUrl = _supabaseService.getPublicUrl('learning-content', coverImagePath);
        // DEBUG: Log generated URL
        print('🔗 Generated Image URL: $imageUrl');
      } else {
        print('⚠ No cover image path found for learning: ${learning['id']}');
      }

      double progress = 0.0;
      String category = 'notstarted';

      if (user != null) {
        // Calculate progress from learning_progress
        final progressData = learning['progress'] as List?;
        if (progressData != null && progressData.isNotEmpty) {
          final progressItem = progressData.first as Map<String, dynamic>;
          progress = (progressItem['progress_percentage'] as num?)?.toDouble() ?? 0.0;
          
          if (progress >= 1.0) {
            category = 'complete';
          } else if (progress > 0.0) {
            category = 'inprogress';
          }
        }
      }

      processedCourses.add({
        'id': learning['id'],
        'title': learning['title'] ?? 'Untitled',
        'description': learning['description'] ?? '',
        'imageUrl': imageUrl,
        'progress': progress,
        'category': category,
        'raw': learning,
        'total_lessons': learning['total_lessons'] ?? 0,
      });
    }

    setState(() {
      _allCourses = processedCourses;
      _isLoading = false;
      _shouldRefresh = false;
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
      return _allCourses;
    }

    final query = _searchQuery.trim().toLowerCase();
    return _allCourses.where((course) {
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
    final completeCourses = filteredCourses.where((c) => c['category'] == 'complete').toList();
    final inProgressCourses = filteredCourses.where((c) => c['category'] == 'inprogress').toList();

    return Scaffold(
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
            if (newLearning != null && newLearning['id'] != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Learning created successfully!')),
              );
              _loadLearnings();
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
                    child: _buildListUI(
                      context, 
                      filteredCourses, 
                      completeCourses, 
                      inProgressCourses, 
                      filteredCourses.isEmpty,
                      isDarkMode
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildListUI(
    BuildContext context,
    List<Map<String, dynamic>> allCoursesFiltered,
    List<Map<String, dynamic>> completeCourses,
    List<Map<String, dynamic>> inProgressCourses,
    bool isEmpty,
    bool isDarkMode,
  ) {
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
                MaterialPageRoute(
                  builder: (context) => LearningHubCompleteScreen(
                    courses: completeCourses,
                  ),
                ),
              ).then((_) {
                _loadLearnings();
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
                MaterialPageRoute(
                  builder: (context) => LearningHubInprogressScreen(
                    courses: inProgressCourses,
                  ),
                ),
              ).then((_) {
                _loadLearnings();
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
                MaterialPageRoute(
                  builder: (context) => LearningHubAllScreen(
                    courses: allCoursesFiltered,
                  ),
                ),
              ).then((_) {
                _loadLearnings();
              });
            }, textColor),
            const SizedBox(height: 12.0),
            ...allCoursesFiltered.take(2).map((course) => _learningItemCardFromMap(course, cardColor, textColor)),
          ],
          if (isEmpty) 
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 40.0),
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
            totalLessons: course['total_lessons'] ?? 0,
          ),
        ),
      ).then((_) {
        _loadLearnings();
      });
    },
    child: Container(
      margin: const EdgeInsets.only(bottom: 8.0),
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
              // Image dengan better error handling
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
                    print('❌ Error loading image: $error');
                    print('📁 Image URL: $imageUrl');
                    return Container(
                      width: 60,
                      height: 60,
                      color: Colors.grey[100],
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.broken_image, color: Colors.grey, size: 24),
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