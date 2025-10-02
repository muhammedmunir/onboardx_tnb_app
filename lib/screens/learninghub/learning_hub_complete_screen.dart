import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'learning_hub_detail_screen.dart';

class LearningHubCompleteScreen extends StatefulWidget {
  final List<Map<String, dynamic>> courses;

  const LearningHubCompleteScreen({
    super.key,
    required this.courses,
  });

  @override
  State<LearningHubCompleteScreen> createState() => _LearningHubCompleteScreenState();
}

class _LearningHubCompleteScreenState extends State<LearningHubCompleteScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text;
    });
  }

  List<Map<String, dynamic>> _getFilteredCourses() {
    // Filter hanya course yang complete (progress = 1.0)
    final completeCourses = widget.courses.where((course) {
      final progress = course['progress'] ?? 0.0;
      return progress >= 1.0;
    }).toList();

    if (_searchQuery.isEmpty) {
      return completeCourses;
    }

    final query = _searchQuery.trim().toLowerCase();
    return completeCourses.where((course) {
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
          'Completed Courses',
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
            child: filteredCourses.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 40.0),
                      child: Text(
                        'No courses found',
                        style: TextStyle(fontSize: 18.0, color: Colors.grey),
                      ),
                    ),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 16.0),
                    child: Column(
                      children: [
                        ...filteredCourses.map((course) => _learningItemCardFromMap(course, cardColor, textColor)),
                      ],
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
        );
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