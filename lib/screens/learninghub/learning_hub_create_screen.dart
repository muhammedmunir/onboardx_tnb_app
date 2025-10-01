// learning_hub_create_screen.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import 'package:onboardx_tnb_app/services/supabase_service.dart';
import 'package:path/path.dart' as p;

class Lesson {
  String title;
  String description;
  String contentType; // 'Document' or 'Video'
  // contentFile will hold the local file selected (not uploaded yet)
  File? contentFile;
  // contentPath will hold the storage path saved to DB (e.g. "documents/...")
  String? contentPath;

  Lesson({
    required this.title,
    required this.description,
    required this.contentType,
    this.contentFile,
    this.contentPath,
  });

  Map<String, dynamic> toMapForDb(String learnId) {
    return {
      'learnid': learnId,
      'title': title,
      'description': description,
      'contenttype': contentType,
      'contentfile': contentPath ?? '',
      'file': contentPath ?? '',
    };
  }
}

class LearningHubCreateScreen extends StatefulWidget {
  const LearningHubCreateScreen({super.key});

  @override
  State<LearningHubCreateScreen> createState() => _LearningHubCreateScreenState();
}

class _LearningHubCreateScreenState extends State<LearningHubCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  File? _coverImageFile;
  String? _coverImagePath; // path in supabase storage (saved to DB)

  List<Lesson> _lessons = [];
  final List<String> _contentTypes = ['Document', 'Video'];
  bool _isLoading = false;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final SupabaseService _supabaseService = SupabaseService();

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
      ));
    });
  }

  void _removeLesson(int index) {
    setState(() {
      _lessons.removeAt(index);
    });
  }

  Future<void> _pickCoverImage() async {
    try {
      final allowed = SupabaseService.supportedImageFormats;
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: allowed,
        withData: false,
      );
      if (result == null) return;
      final pickedPath = result.files.single.path;
      if (pickedPath == null) return;
      setState(() {
        _coverImageFile = File(pickedPath);
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to pick cover image: $e')),
      );
    }
  }

  Future<void> _pickLessonFile(int index) async {
    try {
      final lesson = _lessons[index];
      List<String> allowed;
      FileType type = FileType.custom;

      if (lesson.contentType == 'Video') {
        allowed = ['mp4', 'mov', 'mkv', 'webm', 'avi'];
      } else {
        // Document
        allowed = ['pdf', 'doc', 'docx', 'ppt', 'pptx', 'txt', 'csv', 'xlsx'];
      }

      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: allowed,
        withData: false,
      );

      if (result == null) return;
      final pickedPath = result.files.single.path;
      if (pickedPath == null) return;

      setState(() {
        _lessons[index].contentFile = File(pickedPath);
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to pick file for lesson ${index + 1}: $e')),
      );
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    if (_coverImageFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please choose a cover image')),
      );
      return;
    }

    if (_lessons.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one lesson')),
      );
      return;
    }

    for (int i = 0; i < _lessons.length; i++) {
      final l = _lessons[i];
      if (l.title.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lesson ${i + 1} must have a title')),
        );
        return;
      }
      if (l.contentFile == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lesson ${i + 1} must have a file selected')),
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
      // 1) Upload cover image to bucket 'learning-content'
      final coverExt = p.extension(_coverImageFile!.path).replaceFirst('.', '');
      final coverFileName = 'cover_${DateTime.now().millisecondsSinceEpoch}$coverExt';
      final coverPath = 'coverimages/${user.uid}/${DateTime.now().millisecondsSinceEpoch}${p.extension(_coverImageFile!.path)}';
      // uploadFileWithOverwrite returns path (as implemented in SupabaseService)
      final uploadedCoverResponse = await _supabaseService.uploadFileWithOverwrite(
        'learning-content',
        coverPath,
        _coverImageFile!,
      );
      // store path (we expect service returns stored path or something sensible)
      _coverImagePath = coverPath;

      // 2) Insert learns row
      final learnInsert = {
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'coverimage': _coverImagePath,
        'totallessons': _lessons.length,
        'createdat': DateTime.now().toUtc().toIso8601String(),
        // you can add created_by if schema supports it
      };

      final supabaseClient = _supabaseService.client;
      final insertedLearn = await supabaseClient
          .from('learns')
          .insert(learnInsert)
          .select()
          .maybeSingle();

      if (insertedLearn == null) {
        throw Exception('Failed to insert learning (no row returned)');
      }

      final learnId = insertedLearn['uid'] as String?;

      if (learnId == null) {
        throw Exception('Failed to get learn id after insert');
      }

      // 3) For each lesson: upload file to appropriate bucket and insert lesson row
      for (int i = 0; i < _lessons.length; i++) {
        final lesson = _lessons[i];
        final localFile = lesson.contentFile!;
        final ext = p.extension(localFile.path);
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final safeFileName = '${timestamp}_${p.basename(localFile.path)}';
        final bucket = lesson.contentType == 'Video' ? 'videos' : 'documents';
        final storagePath = '${lesson.contentType.toLowerCase()}/${learnId}/$safeFileName';

        await _supabaseService.uploadFileWithOverwrite(bucket, storagePath, localFile);

        // Save the storage path into lesson object
        lesson.contentPath = storagePath;

        // Insert lesson row
        final lessonRow = {
          'learnid': learnId,
          'title': lesson.title.trim(),
          'description': lesson.description.trim(),
          'contenttype': lesson.contentType,
          'contentfile': lesson.contentPath ?? '',
          'file': lesson.contentPath ?? '',
          'createdat': DateTime.now().toUtc().toIso8601String(),
        };

        final insertedLesson = await supabaseClient.from('lessons').insert(lessonRow).select().maybeSingle();
        if (insertedLesson == null) {
          throw Exception('Failed to insert lesson ${i + 1}');
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Learning created successfully!')),
      );

      // Return to previous screen and optionally pass created learn id
      if (mounted) Navigator.of(context).pop({'id': insertedLearn['uid']});
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

  Widget _buildCoverPicker(Color textColor, Color hintColor, Color fieldFillColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Cover Image', style: TextStyle(color: textColor, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Row(
          children: [
            if (_coverImageFile != null)
              Container(
                width: 80,
                height: 80,
                clipBehavior: Clip.hardEdge,
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(8)),
                child: Image.file(_coverImageFile!, fit: BoxFit.cover),
              )
            else
              Container(
                width: 80,
                height: 80,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: fieldFillColor,
                ),
                child: Icon(Icons.image, color: hintColor),
              ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _coverImageFile != null ? p.basename(_coverImageFile!.path) : 'No image selected',
                    style: TextStyle(color: textColor),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: _isLoading ? null : _pickCoverImage,
                        icon: const Icon(Icons.upload_file),
                        label: const Text('Choose Image'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color.fromRGBO(224, 124, 124, 1),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (_coverImageFile != null)
                        TextButton(
                          onPressed: _isLoading
                              ? null
                              : () {
                                  setState(() {
                                    _coverImageFile = null;
                                    _coverImagePath = null;
                                  });
                                },
                          child: Text('Remove', style: TextStyle(color: hintColor)),
                        ),
                    ],
                  ),
                ],
              ),
            )
          ],
        ),
      ],
    );
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
        title: Text('Create New Learning', style: TextStyle(color: textColor)),
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
              child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 16),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _submitForm,
            child: _isLoading
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Save', style: TextStyle(color: Colors.blue, fontSize: 16.0, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _buildCoverPicker(textColor, hintColor, fieldFillColor),
                  const SizedBox(height: 20),

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

                  const SizedBox(height: 20),

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

                  const SizedBox(height: 20),

                  // Lessons Header
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text('Lessons', style: TextStyle(fontSize: 20.0, fontWeight: FontWeight.bold, color: textColor)),
                    IconButton(onPressed: _addNewLesson, icon: Icon(Icons.add, color: textColor), tooltip: 'Add Lesson'),
                  ]),

                  const SizedBox(height: 10),

                  if (_lessons.isEmpty)
                    Center(child: Text('No lessons added yet. Click + to add a lesson.', style: TextStyle(color: hintColor)))
                  else
                    ..._lessons.asMap().entries.map((entry) {
                      final index = entry.key;
                      final lesson = entry.value;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 16.0),
                        color: cardColor,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                              Text('Lesson ${index + 1}', style: TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold, color: textColor)),
                              IconButton(onPressed: () => _removeLesson(index), icon: const Icon(Icons.delete), color: Colors.red),
                            ]),
                            const SizedBox(height: 10),
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
                            const SizedBox(height: 10),
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
                            const SizedBox(height: 10),
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
                                return DropdownMenuItem<String>(value: type, child: Text(type, style: TextStyle(color: textColor)));
                              }).toList(),
                              onChanged: (String? newValue) {
                                setState(() {
                                  _lessons[index].contentType = newValue!;
                                  _lessons[index].contentFile = null; // reset file when type changes
                                });
                              },
                            ),
                            const SizedBox(height: 10),
                            // File picker row
                            Row(children: [
                              Expanded(
                                child: Text(
                                  lesson.contentFile != null ? p.basename(lesson.contentFile!.path) : (lesson.contentPath ?? 'No file selected'),
                                  style: TextStyle(color: textColor),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton.icon(
                                onPressed: () => _pickLessonFile(index),
                                icon: const Icon(Icons.upload_file),
                                label: const Text('Choose File'),
                                style: ElevatedButton.styleFrom(backgroundColor: const Color.fromRGBO(224, 124, 124, 1)),
                              ),
                              const SizedBox(width: 8),
                              if (lesson.contentFile != null || (lesson.contentPath != null && lesson.contentPath!.isNotEmpty))
                                TextButton(
                                  onPressed: () {
                                    setState(() {
                                      lesson.contentFile = null;
                                      lesson.contentPath = null;
                                    });
                                  },
                                  child: Text('Remove', style: TextStyle(color: hintColor)),
                                )
                            ]),
                          ]),
                        ),
                      );
                    }).toList(),

                  const SizedBox(height: 30),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _submitForm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color.fromRGBO(224, 124, 124, 1),
                        padding: const EdgeInsets.symmetric(vertical: 16.0),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('Create Learning', style: TextStyle(color: Colors.white, fontSize: 16.0, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ]),
              ),
            ),
    );
  }
}
