import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LearningHubCreateScreen extends StatefulWidget {
  const LearningHubCreateScreen({super.key});

  @override
  State<LearningHubCreateScreen> createState() => _LearningHubCreateScreenState();
}

class Lesson {
  String title;
  String description;
  String contentType; // 'Document', 'Video'
  String contentUrl; // URL untuk konten

  Lesson({
    required this.title,
    required this.description,
    required this.contentType,
    required this.contentUrl,
  });

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'contentType': contentType,
      'contentUrl': contentUrl,
    };
  }
}

class _LearningHubCreateScreenState extends State<LearningHubCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _coverImageUrlController = TextEditingController();

  List<Lesson> _lessons = [];
  final List<String> _contentTypes = ['Document', 'Video'];
  bool _isLoading = false;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _coverImageUrlController.dispose();
    super.dispose();
  }

  void _addNewLesson() {
    setState(() {
      _lessons.add(Lesson(
        title: '',
        description: '',
        contentType: 'Document',
        contentUrl: '',
      ));
    });
  }

  void _removeLesson(int index) {
    setState(() {
      _lessons.removeAt(index);
    });
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    if (_coverImageUrlController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please provide a cover image URL')),
      );
      return;
    }
    if (_lessons.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one lesson')),
      );
      return;
    }
    for (var lesson in _lessons) {
      if (lesson.title.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All lessons must have a title')),
        );
        return;
      }
      if (lesson.contentUrl.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All lessons must have a content URL')),
        );
        return;
      }
    }

    final user = _auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be signed in to create a learning')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      List<Map<String, dynamic>> lessonsData =
          _lessons.map((lesson) => lesson.toMap()).toList();

      final docRef = await _firestore.collection('learnings').add({
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'coverImageUrl': _coverImageUrlController.text.trim(),
        'lessons': lessonsData,
        //'progress': 0.0,
        'createdAt': FieldValue.serverTimestamp(),
        'totalLessons': lessonsData.length,
        'createdBy': user.uid, // **PENTING** — mesti padankan dengan rules
      });

      // Tunjuk snackbar kejayaan sebelum pop (atau pass result)
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Learning created successfully!')),
      );

      // Kembali ke screen sebelum ini (boleh pass docRef.id kalau nak)
      Navigator.of(context).pop({'id': docRef.id});
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error creating learning: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final Color scaffoldBackground = Theme.of(context).scaffoldBackgroundColor;
    final Color textColor = Theme.of(context).colorScheme.onBackground;
    final Color cardColor = Theme.of(context).cardColor;
    final Color hintColor = isDarkMode ? Colors.grey[400]! : Colors.grey[600]!;
    final Color fieldFillColor = isDarkMode ? Colors.grey[800]! : Colors.grey[100]!;

    return Scaffold(
      backgroundColor: scaffoldBackground,
      appBar: AppBar(
        title: Text(
          'Create New Learning',
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
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _submitForm,
            child: _isLoading
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text(
                    'Save',
                    style: TextStyle(
                      color: Colors.blue,
                      fontSize: 16.0,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Cover Image URL
                    TextFormField(
                      controller: _coverImageUrlController,
                      style: TextStyle(color: textColor),
                      decoration: InputDecoration(
                        labelText: 'Cover Image URL',
                        labelStyle: TextStyle(color: hintColor),
                        hintText: 'https://example.com/image.jpg',
                        hintStyle: TextStyle(color: hintColor),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.0),
                          borderSide: BorderSide(color: isDarkMode ? Colors.grey[700]! : Colors.grey[300]!),
                        ),
                        filled: true,
                        fillColor: fieldFillColor,
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please provide a cover image URL';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20.0),

                    // Title Field
                    TextFormField(
                      controller: _titleController,
                      style: TextStyle(color: textColor),
                      decoration: InputDecoration(
                        labelText: 'Course Title',
                        labelStyle: TextStyle(color: hintColor),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.0),
                          borderSide: BorderSide(color: isDarkMode ? Colors.grey[700]! : Colors.grey[300]!),
                        ),
                        filled: true,
                        fillColor: fieldFillColor,
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a course title';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 20.0),

                    // Description Field
                    TextFormField(
                      controller: _descriptionController,
                      style: TextStyle(color: textColor),
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: 'Course Description',
                        labelStyle: TextStyle(color: hintColor),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.0),
                          borderSide: BorderSide(color: isDarkMode ? Colors.grey[700]! : Colors.grey[300]!),
                        ),
                        filled: true,
                        fillColor: fieldFillColor,
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a course description';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 20.0),

                    // Lessons Header
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
                        IconButton(
                          onPressed: _addNewLesson,
                          icon: Icon(Icons.add, color: textColor),
                          tooltip: 'Add Lesson',
                        ),
                      ],
                    ),

                    const SizedBox(height: 10.0),

                    if (_lessons.isEmpty)
                      Center(
                        child: Text(
                          'No lessons added yet. Click + to add a lesson.',
                          style: TextStyle(color: hintColor),
                        ),
                      )
                    else
                      ..._lessons.asMap().entries.map((entry) {
                        final index = entry.key;
                        final lesson = entry.value;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 16.0),
                          color: cardColor,
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Lesson ${index + 1}',
                                      style: TextStyle(
                                        fontSize: 18.0,
                                        fontWeight: FontWeight.bold,
                                        color: textColor,
                                      ),
                                    ),
                                    IconButton(
                                      onPressed: () => _removeLesson(index),
                                      icon: const Icon(Icons.delete),
                                      color: Colors.red,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10.0),
                                TextFormField(
                                  initialValue: lesson.title,
                                  style: TextStyle(color: textColor),
                                  decoration: InputDecoration(
                                    labelText: 'Lesson Title',
                                    labelStyle: TextStyle(color: hintColor),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8.0),
                                      borderSide: BorderSide(color: isDarkMode ? Colors.grey[700]! : Colors.grey[300]!),
                                    ),
                                    filled: true,
                                    fillColor: fieldFillColor,
                                  ),
                                  onChanged: (value) {
                                    setState(() {
                                      _lessons[index].title = value;
                                    });
                                  },
                                ),
                                const SizedBox(height: 10.0),
                                TextFormField(
                                  initialValue: lesson.description,
                                  style: TextStyle(color: textColor),
                                  maxLines: 2,
                                  decoration: InputDecoration(
                                    labelText: 'Lesson Description',
                                    labelStyle: TextStyle(color: hintColor),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8.0),
                                      borderSide: BorderSide(color: isDarkMode ? Colors.grey[700]! : Colors.grey[300]!),
                                    ),
                                    filled: true,
                                    fillColor: fieldFillColor,
                                  ),
                                  onChanged: (value) {
                                    setState(() {
                                      _lessons[index].description = value;
                                    });
                                  },
                                ),
                                const SizedBox(height: 10.0),
                                DropdownButtonFormField<String>(
                                  value: lesson.contentType,
                                  dropdownColor: isDarkMode ? Colors.grey[800] : Colors.white,
                                  style: TextStyle(color: textColor),
                                  decoration: InputDecoration(
                                    labelText: 'Content Type',
                                    labelStyle: TextStyle(color: hintColor),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8.0),
                                      borderSide: BorderSide(color: isDarkMode ? Colors.grey[700]! : Colors.grey[300]!),
                                    ),
                                    filled: true,
                                    fillColor: fieldFillColor,
                                  ),
                                  items: _contentTypes.map((String type) {
                                    return DropdownMenuItem<String>(
                                      value: type,
                                      child: Text(type, style: TextStyle(color: textColor)),
                                    );
                                  }).toList(),
                                  onChanged: (String? newValue) {
                                    setState(() {
                                      _lessons[index].contentType = newValue!;
                                    });
                                  },
                                ),
                                const SizedBox(height: 10.0),
                                TextFormField(
                                  initialValue: lesson.contentUrl,
                                  style: TextStyle(color: textColor),
                                  decoration: InputDecoration(
                                    labelText: 'Content URL',
                                    labelStyle: TextStyle(color: hintColor),
                                    hintText: 'https://example.com/content',
                                    hintStyle: TextStyle(color: hintColor),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8.0),
                                      borderSide: BorderSide(color: isDarkMode ? Colors.grey[700]! : Colors.grey[300]!),
                                    ),
                                    filled: true,
                                    fillColor: fieldFillColor,
                                  ),
                                  onChanged: (value) {
                                    setState(() {
                                      _lessons[index].contentUrl = value;
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),

                    const SizedBox(height: 30.0),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _submitForm,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color.fromRGBO(224, 124, 124, 1),
                          padding: const EdgeInsets.symmetric(vertical: 16.0),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.0),
                          ),
                        ),
                        child: _isLoading
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text(
                                'Create Learning',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16.0,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}