import 'dart:io';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:onboardx_tnb_app/services/supabase_service.dart';

class LearningHubCreateScreen extends StatefulWidget {
  const LearningHubCreateScreen({super.key});

  @override
  State<LearningHubCreateScreen> createState() => _LearningHubCreateScreenState();
}

class Lesson {
  String title;
  String description;
  String contentType; // 'Document', 'Video'
  String contentPath; // Path untuk konten di storage
  FilePickerResult? contentFile; // File yang dipilih

  Lesson({
    required this.title,
    required this.description,
    required this.contentType,
    required this.contentPath,
    this.contentFile,
  });

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'content_type': contentType,
      'content_path': contentPath,
    };
  }
}

class _LearningHubCreateScreenState extends State<LearningHubCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  List<Lesson> _lessons = [];
  final List<String> _contentTypes = ['Document', 'Video'];
  bool _isLoading = false;

  final SupabaseService _supabaseService = SupabaseService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // File untuk cover image
  PlatformFile? _coverImageFile;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _addNewLesson() {
    setState(() {
      _lessons.add(Lesson(
        title: '',
        description: '',
        contentType: 'Document',
        contentPath: '',
      ));
    });
  }

  void _removeLesson(int index) {
    setState(() {
      _lessons.removeAt(index);
    });
  }

  // Method untuk memilih cover image
  Future<void> _pickCoverImage() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _coverImageFile = result.files.first;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking image: $e')),
      );
    }
  }

  // Method untuk memilih file konten lesson
  Future<void> _pickLessonContent(int index) async {
    try {
      final lesson = _lessons[index];
      FileType fileType = lesson.contentType == 'Video' ? FileType.video : FileType.custom;
      
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: fileType,
        allowMultiple: false,
        allowedExtensions: lesson.contentType == 'Document' 
            ? ['pdf', 'doc', 'docx', 'txt'] 
            : null,
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _lessons[index].contentFile = result;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking file: $e')),
      );
    }
  }

  // Upload cover image ke Supabase
Future<String?> _uploadCoverImage() async {
  if (_coverImageFile == null) return null;

  try {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not logged in');

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fileExtension = _coverImageFile!.extension ?? 'jpg';
    final fileName = 'cover_${user.uid}_$timestamp.$fileExtension';
    final path = 'covers/$fileName';

    print('🖼 Uploading cover image:');
    print('📁 Bucket: learning-content');
    print('📁 Path: $path');
    print('📁 File: ${_coverImageFile!.name}');

    // Convert PlatformFile to File
    final file = await _convertPlatformFileToFile(_coverImageFile!);
    
    final uploadedPath = await _supabaseService.uploadFileWithOverwrite(
      'learning-content',
      path,
      file,
    );

    print('✅ Cover image uploaded successfully: $uploadedPath');
    
    // Test public URL
    final testUrl = _supabaseService.getPublicUrl('learning-content', uploadedPath);
    print('🔗 Test Public URL: $testUrl');

    return uploadedPath;
  } catch (e) {
    print('❌ Failed to upload cover image: $e');
    throw Exception('Failed to upload cover image: $e');
  }
}

// Upload lesson content ke Supabase
Future<String> _uploadLessonContent(Lesson lesson) async {
  if (lesson.contentFile == null || lesson.contentFile!.files.isEmpty) {
    throw Exception('No file selected for lesson');
  }

  try {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not logged in');

    final file = lesson.contentFile!.files.first;
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    
    // Sanitize title untuk filename
    final sanitizedTitle = lesson.title.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
    final fileExtension = file.extension ?? 
        (lesson.contentType == 'Video' ? 'mp4' : 'pdf');
    final fileName = 'content_${user.uid}_${sanitizedTitle}_$timestamp.$fileExtension';
    
    // Tentukan bucket berdasarkan content type
    final bucket = lesson.contentType == 'Video' ? 'videos' : 'documents';
    
    // PERBAIKAN: Hapus duplikasi bucket name di path
    final path = fileName; // Hanya filename, tanpa folder

    // Convert PlatformFile to File
    final dartFile = await _convertPlatformFileToFile(file);
    
    final uploadedPath = await _supabaseService.uploadFileWithOverwrite(
      bucket,
      path,
      dartFile,
    );

    return uploadedPath;
  } catch (e) {
    throw Exception('Failed to upload lesson content: $e');
  }
}

  // Helper method untuk convert PlatformFile ke File
  Future<File> _convertPlatformFileToFile(PlatformFile platformFile) async {
    // Since PlatformFile doesn't directly give us a File, we need to handle this differently
    // In a real app, you might want to use the path directly or copy the file
    // For now, we'll use the path if available, otherwise we'll need to handle bytes
    if (platformFile.path != null) {
      return File(platformFile.path!);
    } else {
      // If path is null (web), we need to handle differently
      // This is a simplified version - you might need more complex handling for web
      throw Exception('File path not available. Web support may require additional setup.');
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    if (_coverImageFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a cover image')),
      );
      return;
    }
    if (_lessons.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one lesson')),
      );
      return;
    }

    // Validasi setiap lesson
    for (var i = 0; i < _lessons.length; i++) {
      final lesson = _lessons[i];
      if (lesson.title.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lesson ${i + 1} must have a title')),
        );
        return;
      }
      if (lesson.contentFile == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lesson ${i + 1} must have a content file')),
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
      // 1. Upload cover image
      final coverImagePath = await _uploadCoverImage();
      if (coverImagePath == null) {
        throw Exception('Failed to upload cover image');
      }

      // 2. Create learning record
      final learningData = {
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'cover_image_path': coverImagePath,
        'created_by': user.uid,
        'total_lessons': _lessons.length,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      };

      final learningResponse = await _supabaseService.client
          .from('learnings')
          .insert(learningData)
          .select()
          .single();

      final learningId = learningResponse['id'] as int;

      // 3. Upload lesson contents dan create lesson records
      for (int i = 0; i < _lessons.length; i++) {
        final lesson = _lessons[i];
        final contentPath = await _uploadLessonContent(lesson);

        final lessonData = {
          'learning_id': learningId,
          'title': lesson.title,
          'description': lesson.description,
          'content_type': lesson.contentType,
          'content_path': contentPath,
          'order_index': i,
          'created_at': DateTime.now().toUtc().toIso8601String(),
        };

        await _supabaseService.client
            .from('lessons')
            .insert(lessonData);
      }

      // Tunjuk snackbar kejayaan
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Learning created successfully!')),
      );

      // Kembali ke screen sebelum ini
      Navigator.of(context).pop({'id': learningId});
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
                    // Cover Image Upload
                    Card(
                      color: cardColor,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Cover Image',
                              style: TextStyle(
                                fontSize: 16.0,
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                            ),
                            const SizedBox(height: 10.0),
                            _coverImageFile == null
                                ? OutlinedButton(
                                    onPressed: _pickCoverImage,
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: textColor,
                                      side: BorderSide(color: hintColor),
                                    ),
                                    child: const Text('Select Cover Image'),
                                  )
                                : Column(
                                    children: [
                                      Text(
                                        _coverImageFile!.name,
                                        style: TextStyle(color: textColor),
                                      ),
                                      const SizedBox(height: 10.0),
                                      Row(
                                        children: [
                                          OutlinedButton(
                                            onPressed: _pickCoverImage,
                                            child: const Text('Change Image'),
                                          ),
                                          const SizedBox(width: 10.0),
                                          OutlinedButton(
                                            onPressed: () {
                                              setState(() {
                                                _coverImageFile = null;
                                              });
                                            },
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: Colors.red,
                                            ),
                                            child: const Text('Remove'),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                          ],
                        ),
                      ),
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
                                      // Reset file ketika content type berubah
                                      _lessons[index].contentFile = null;
                                    });
                                  },
                                ),
                                const SizedBox(height: 10.0),
                                lesson.contentFile == null
                                    ? OutlinedButton(
                                        onPressed: () => _pickLessonContent(index),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: textColor,
                                          side: BorderSide(color: hintColor),
                                        ),
                                        child: Text('Select ${lesson.contentType} File'),
                                      )
                                    : Column(
                                        children: [
                                          Text(
                                            lesson.contentFile!.files.first.name,
                                            style: TextStyle(color: textColor),
                                          ),
                                          const SizedBox(height: 10.0),
                                          Row(
                                            children: [
                                              OutlinedButton(
                                                onPressed: () => _pickLessonContent(index),
                                                child: Text('Change ${lesson.contentType} File'),
                                              ),
                                              const SizedBox(width: 10.0),
                                              OutlinedButton(
                                                onPressed: () {
                                                  setState(() {
                                                    _lessons[index].contentFile = null;
                                                  });
                                                },
                                                style: OutlinedButton.styleFrom(
                                                  foregroundColor: Colors.red,
                                                ),
                                                child: const Text('Remove'),
                                              ),
                                            ],
                                          ),
                                        ],
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