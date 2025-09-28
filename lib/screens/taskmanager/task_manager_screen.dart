import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:open_filex/open_filex.dart'; // Import the package
import 'dart:io' as io;

class TaskManagerScreen extends StatelessWidget {
  const TaskManagerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final Color scaffoldBackground = Theme.of(context).scaffoldBackgroundColor;
    final Color textColor = Theme.of(context).colorScheme.onBackground;
    final Color hintColor = isDarkMode ? Colors.grey[400]! : Colors.grey[600]!;

    return Scaffold(
      backgroundColor: scaffoldBackground,
      appBar: AppBar(
        title: Text(
          'Task Manager',
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Required Documents',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
            ),
            const SizedBox(height: 16),
            DocumentCard(
              title: 'Lampiran A',
              subtitle: 'Upload the required files',
              subtitleColor: hintColor,
            ),
            const SizedBox(height: 12),
            DocumentCard(
              title: 'Sijil Tanggung Diri',
              subtitle: 'Upload the required files',
              subtitleColor: hintColor,
            ),
            const SizedBox(height: 12),
            DocumentCard(
              title: 'Penyata Bank',
              subtitle: 'Upload the required files',
              subtitleColor: hintColor,
            ),
            const SizedBox(height: 32),
            // Private Details and Certs Section
            Text(
              'Private Details and Certs',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
            ),
            const SizedBox(height: 16),
            DocumentCard(
              title: 'Identity Card (IC)',
              subtitle: 'Upload Required',
              subtitleColor: hintColor,
            ),
            const SizedBox(height: 12),
            DocumentCard(
              title: 'Driving License',
              subtitle: 'Optional',
              subtitleColor: hintColor,
            ),
            const SizedBox(height: 12),
            DocumentCard(
              title: 'Certificates',
              subtitle: 'Optional',
              subtitleColor: hintColor,
            ),
          ],
        ),
      ),
    );
  }
}

class DocumentCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final Color? subtitleColor;
  final String? initialFile;

  const DocumentCard({
    super.key,
    required this.title,
    required this.subtitle,
    this.subtitleColor,
    this.initialFile,
  });

  @override
  State<DocumentCard> createState() => _DocumentCardState();
}

class _DocumentCardState extends State<DocumentCard> {
  String? _selectedFileName;
  String? _selectedFilePath; // New state variable to store the file path
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    // Initialize file name and path if an initial file is provided
    if (widget.initialFile != null) {
      // Note: This assumes the initialFile path is valid and accessible.
      // In a real app, you would fetch this path from a database or a file system.
      _selectedFileName = widget.initialFile;
      _selectedFilePath = widget.initialFile;
    }
  }

  Future<void> _pickFile() async {
    setState(() {
      _isUploading = true;
    });

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles();
      if (result != null) {
        PlatformFile file = result.files.first;
        setState(() {
          _selectedFileName = file.name;
          _selectedFilePath = file.path; // Store the absolute path
        });
        // Simulate upload delay
        await Future.delayed(const Duration(seconds: 2));
        _showSnackbar('File "${file.name}" selected successfully!');
      } else {
        _showSnackbar('File selection canceled.');
      }
    } catch (e) {
      _showSnackbar('Error picking file: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  Future<void> _openFile() async {
    // Now we check for the file path, which is the correct way
    if (_selectedFilePath != null) {
      final result = await OpenFilex.open(_selectedFilePath!);
      if (result.type != ResultType.done) {
        _showSnackbar('Error opening file: ${result.message}');
      } else {
        _showSnackbar('File "$_selectedFileName" opened successfully.');
      }
    } else {
      _showSnackbar('No file selected to open.');
    }
  }

  void _removeFile() {
    setState(() {
      _selectedFileName = null;
      _selectedFilePath = null; // Also clear the path
      _showSnackbar('File removed successfully!');
    });
  }

  void _showSnackbar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final Color cardColor = Theme.of(context).cardColor;
    final Color textColor = Theme.of(context).colorScheme.onBackground;
    final Color hintColor = isDarkMode ? Colors.grey[400]! : Colors.grey[600]!;
    final Color borderColor = isDarkMode ? Colors.grey[700]! : Colors.grey[300]!;

    final bool hasFile = _selectedFilePath != null; // Use the path to check for a file

    IconData cardIcon;
    Color cardIconColor;
    String currentSubtitle;
    Color currentSubtitleColor;

    if (_isUploading) {
      cardIcon = Icons.upload_file;
      cardIconColor = Colors.blue;
      currentSubtitle = 'Uploading...';
      currentSubtitleColor = Colors.blue[600]!;
    } else if (hasFile) {
      cardIcon = Icons.check_circle;
      cardIconColor = Colors.green;
      currentSubtitle = _selectedFileName!;
      currentSubtitleColor = Colors.green;
    } else {
      cardIcon = Icons.add_circle;
      cardIconColor = hintColor;
      currentSubtitle = widget.subtitle;
      currentSubtitleColor = widget.subtitleColor ?? hintColor;
    }

    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: isDarkMode ? 0 : 1,
      color: cardColor,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: cardIconColor.withOpacity(0.1),
              ),
              child: _isUploading
                  ? SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(cardIconColor),
                        strokeWidth: 3,
                      ),
                    )
                  : Icon(
                      cardIcon,
                      color: cardIconColor,
                      size: 24,
                    ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    currentSubtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: currentSubtitleColor,
                      fontStyle: hasFile ? FontStyle.italic : null,
                    ),
                  ),
                ],
              ),
            ),
            // Actions (Upload/View/Edit/Remove)
            if (_isUploading)
              Text('Uploading...', style: TextStyle(color: Colors.blue[600]))
            else if (hasFile)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: 30,
                    child: OutlinedButton(
                      onPressed: _openFile,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: hintColor,
                        side: BorderSide(color: borderColor),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        visualDensity: VisualDensity.compact,
                      ),
                      child: Text('View', style: TextStyle(fontSize: 13, color: hintColor)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  PopupMenuButton<String>(
                    onSelected: (String result) {
                      if (result == 'edit') {
                        _pickFile();
                      } else if (result == 'remove') {
                        _removeFile();
                      }
                    },
                    itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                      PopupMenuItem<String>(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit, size: 20, color: textColor),
                            const SizedBox(width: 8),
                            Text('Edit', style: TextStyle(color: textColor)),
                          ],
                        ),
                      ),
                      PopupMenuItem<String>(
                        value: 'remove',
                        child: Row(
                          children: [
                            Icon(Icons.delete, size: 20, color: Colors.red),
                            const SizedBox(width: 8),
                            Text('Remove', style: TextStyle(color: textColor)),
                          ],
                        ),
                      ),
                    ],
                    icon: Icon(Icons.more_vert, color: hintColor),
                    padding: EdgeInsets.zero,
                  )
                ],
              )
            else
              SizedBox(
                height: 30,
                child: OutlinedButton(
                  onPressed: _pickFile,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: hintColor,
                    side: BorderSide(color: borderColor),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    visualDensity: VisualDensity.compact,
                  ),
                  child: Text('Upload', style: TextStyle(fontSize: 13, color: hintColor)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}