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
  String contentUrl; // public URL stored in DB
  String? contentFileName; // for UI display
  String? contentStoragePath; // path in bucket (optional)

  Lesson({
    required this.title,
    required this.description,
    required this.contentType,
    required this.contentUrl,
    this.contentFileName,
    this.contentStoragePath,
  });

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'contentType': contentType,
      'contentUrl': contentUrl,
      'contentFileName': contentFileName,
      'contentStoragePath': contentStoragePath,
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
  final TextEditingController _coverImageUrlController = TextEditingController();

  final SupabaseService _supabase = SupabaseService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<Lesson> _lessons = [];
  final List<String> _contentTypes = ['Document', 'Video'];
  bool _isLoading = false;

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

  // PICK & UPLOAD COVER IMAGE
  Future<void> _pickAndUploadCoverImage() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please sign in first')));
        return;
      }

      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: SupabaseService.supportedImageFormats,
        allowMultiple: false,
        withData: false,
      );

      if (result == null || result.files.isEmpty) return;

      final pickedPath = result.files.single.path;
      if (pickedPath == null) return;

      final file = File(pickedPath);
      final fileSize = await file.length();
      if (fileSize > SupabaseService.maxFileSize) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Cover image too large. Max ${SupabaseService.maxFileSize ~/ (1024 * 1024)}MB')),
        );
        return;
      }

      final ext = p.extension(file.path).replaceFirst('.', '');
      final ts = DateTime.now().millisecondsSinceEpoch;
      final storagePath = 'covers/${user.uid}/cover_$ts.$ext';

      setState(() => _isLoading = true);

      // upload to bucket learning-content (overwrite allowed)
      final uploaded = await _supabase.uploadFileWithOverwrite('learning-content', storagePath, file);
      // uploaded should be storage path; get public url
      final publicUrl = _supabase.getPublicUrl('learning-content', uploaded);

      // set controller
      _coverImageUrlController.text = publicUrl;

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cover image uploaded')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to upload cover image: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // PICK & UPLOAD LESSON FILE (document/video depending on lesson.contentType)
  Future<void> _pickAndUploadLessonFile(int index) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please sign in first')));
        return;
      }

      final lesson = _lessons[index];

      FileType pickType = FileType.any;
      List<String>? allowedExt;
      String bucket = 'documents';

      if (lesson.contentType == 'Video') {
        // common video extensions
        allowedExt = ['mp4', 'mov', 'mkv', 'webm', 'avi'];
        bucket = 'videos';
        pickType = FileType.custom;
      } else {
        // documents
        allowedExt = ['pdf', 'doc', 'docx', 'ppt', 'pptx', 'xlsx', 'txt'];
        bucket = 'documents';
        pickType = FileType.custom;
      }

      final result = await FilePicker.platform.pickFiles(
        type: pickType,
        allowedExtensions: allowedExt,
        allowMultiple: false,
        withData: false,
      );

      if (result == null || result.files.isEmpty) return;
      final pickedPath = result.files.single.path;
      if (pickedPath == null) return;
      final file = File(pickedPath);
      final fileSize = await file.length();
      if (fileSize > SupabaseService.maxFileSize) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('File too large. Max ${SupabaseService.maxFileSize ~/ (1024 * 1024)}MB')),
        );
        return;
      }

      final ext = p.extension(file.path).replaceFirst('.', '');
      final ts = DateTime.now().millisecondsSinceEpoch;
      final storagePath = '${bucket}/${user.uid}/${p.basenameWithoutExtension(file.path)}_$ts.$ext';

      setState(() => _isLoading = true);

      final uploaded = await _supabase.uploadFileWithOverwrite(bucket, storagePath, file);
      final publicUrl = _supabase.getPublicUrl(bucket, uploaded);

      setState(() {
        _lessons[index].contentUrl = publicUrl;
        _lessons[index].contentFileName = p.basename(file.path);
        _lessons[index].contentStoragePath = uploaded;
      });

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lesson file uploaded')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to upload lesson file: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    if (_coverImageUrlController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please provide a cover image (upload)')));
      return;
    }
    if (_lessons.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please add at least one lesson')));
      return;
    }
    for (var lesson in _lessons) {
      if (lesson.title.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('All lessons must have a title')));
        return;
      }
      if (lesson.contentUrl.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('All lessons must have a content file (upload)')));
        return;
      }
    }

    final user = _auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('You must be signed in to create a learning')));
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final lessonsData = _lessons.map((l) => l.toMap()).toList();

      // Insert to Supabase Postgres table 'learnings'
      final payload = {
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'cover_image_url': _coverImageUrlController.text.trim(),
        'cover_image_path': null, // optional - could store storage path if you prefer
        'lessons': lessonsData, // jsonb
        'total_lessons': lessonsData.length,
        'created_by': user.uid,
      };

      final response = await _supabase.client.from('learnings').insert(payload).select().maybeSingle();

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Learning created successfully!')));

      // return to previous screen with id if available (response['id'])
      Navigator.of(context).pop({'id': response != null ? response['id'] : null});
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error creating learning: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
        title: Text('Create New Learning', style: TextStyle(color: textColor)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: textColor,
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
                  // Cover Image area (upload)
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _coverImageUrlController,
                          style: TextStyle(color: textColor),
                          decoration: InputDecoration(
                            labelText: 'Cover Image URL (auto after upload)',
                            labelStyle: TextStyle(color: hintColor),
                            hintText: 'Upload a cover image to generate URL',
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
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton(
                        onPressed: _isLoading ? null : _pickAndUploadCoverImage,
                        style: ElevatedButton.styleFrom(backgroundColor: const Color.fromRGBO(224, 124, 124, 1)),
                        child: const Text('Upload'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20.0),

                  // Title Field
                  TextFormField(
                    controller: _titleController,
                    style: TextStyle(color: textColor),
                    decoration: InputDecoration(
                      labelText: 'Course Title',
                      labelStyle: TextStyle(color: hintColor),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.0), borderSide: BorderSide(color: isDarkMode ? Colors.grey[700]! : Colors.grey[300]!)),
                      filled: true,
                      fillColor: fieldFillColor,
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Please enter a course title';
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
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.0), borderSide: BorderSide(color: isDarkMode ? Colors.grey[700]! : Colors.grey[300]!)),
                      filled: true,
                      fillColor: fieldFillColor,
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Please enter a course description';
                      return null;
                    },
                  ),
                  const SizedBox(height: 20.0),

                  // Lessons header
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text('Lessons', style: TextStyle(fontSize: 20.0, fontWeight: FontWeight.bold, color: textColor)),
                    IconButton(onPressed: _addNewLesson, icon: Icon(Icons.add, color: textColor), tooltip: 'Add Lesson'),
                  ]),
                  const SizedBox(height: 10.0),

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
                            const SizedBox(height: 10.0),

                            // Lesson Title
                            TextFormField(
                              initialValue: lesson.title,
                              style: TextStyle(color: textColor),
                              decoration: InputDecoration(
                                labelText: 'Lesson Title',
                                labelStyle: TextStyle(color: hintColor),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0), borderSide: BorderSide(color: isDarkMode ? Colors.grey[700]! : Colors.grey[300]!)),
                                filled: true,
                                fillColor: fieldFillColor,
                              ),
                              onChanged: (value) => setState(() => _lessons[index].title = value),
                            ),
                            const SizedBox(height: 10.0),

                            // Lesson Description
                            TextFormField(
                              initialValue: lesson.description,
                              style: TextStyle(color: textColor),
                              maxLines: 2,
                              decoration: InputDecoration(
                                labelText: 'Lesson Description',
                                labelStyle: TextStyle(color: hintColor),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0), borderSide: BorderSide(color: isDarkMode ? Colors.grey[700]! : Colors.grey[300]!)),
                                filled: true,
                                fillColor: fieldFillColor,
                              ),
                              onChanged: (value) => setState(() => _lessons[index].description = value),
                            ),
                            const SizedBox(height: 10.0),

                            // Content Type dropdown
                            DropdownButtonFormField<String>(
                              value: lesson.contentType,
                              dropdownColor: isDarkMode ? Colors.grey[800] : Colors.white,
                              style: TextStyle(color: textColor),
                              decoration: InputDecoration(
                                labelText: 'Content Type',
                                labelStyle: TextStyle(color: hintColor),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0), borderSide: BorderSide(color: isDarkMode ? Colors.grey[700]! : Colors.grey[300]!)),
                                filled: true,
                                fillColor: fieldFillColor,
                              ),
                              items: _contentTypes.map((String type) => DropdownMenuItem<String>(value: type, child: Text(type, style: TextStyle(color: textColor)))).toList(),
                              onChanged: (String? newValue) => setState(() => _lessons[index].contentType = newValue!),
                            ),
                            const SizedBox(height: 10.0),

                            // Content URL + Upload Button
                            Row(children: [
                              Expanded(
                                child: TextFormField(
                                  initialValue: lesson.contentUrl,
                                  style: TextStyle(color: textColor),
                                  readOnly: true,
                                  decoration: InputDecoration(
                                    labelText: 'Content URL (auto after upload)',
                                    labelStyle: TextStyle(color: hintColor),
                                    hintText: lesson.contentFileName ?? 'Upload a file',
                                    hintStyle: TextStyle(color: hintColor),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0), borderSide: BorderSide(color: isDarkMode ? Colors.grey[700]! : Colors.grey[300]!)),
                                    filled: true,
                                    fillColor: fieldFillColor,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              ElevatedButton(
                                onPressed: _isLoading ? null : () => _pickAndUploadLessonFile(index),
                                style: ElevatedButton.styleFrom(backgroundColor: const Color.fromRGBO(224, 124, 124, 1)),
                                child: const Text('Upload'),
                              ),
                            ]),
                          ]),
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
