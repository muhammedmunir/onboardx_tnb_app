import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChecklistScreen extends StatefulWidget {
  const ChecklistScreen({super.key});

  @override
  State<ChecklistScreen> createState() => _ChecklistScreenState();
}

class _ChecklistScreenState extends State<ChecklistScreen> {
  // Firebase instances
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // Project and task data
  List<Map<String, dynamic>> _projects = [];
  List<Map<String, dynamic>> _tasks = [];
  Map<String, dynamic>? _selectedProject;

  // Controllers for forms
  final TextEditingController _projectTitleController = TextEditingController();
  final TextEditingController _taskTitleController = TextEditingController();
  final TextEditingController _taskDescriptionController = TextEditingController();
  DateTime _projectStartDate = DateTime.now();
  DateTime _projectEndDate = DateTime.now().add(const Duration(days: 7));
  DateTime _taskDueDate = DateTime.now().add(const Duration(days: 1));

  @override
  void initState() {
    super.initState();
    // Load data from Firebase
    _loadProjects();
    _loadTasks();
  }

  @override
  void dispose() {
    _projectTitleController.dispose();
    _taskTitleController.dispose();
    _taskDescriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadProjects() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        final querySnapshot = await _firestore
            .collection('projects')
            .where('userId', isEqualTo: user.uid)
            .get();

        if (!mounted) return; // <<< safety check
        setState(() {
          _projects = querySnapshot.docs.map((doc) {
            final data = doc.data();
            // defensive access in case fields missing
            Timestamp? s = data['startDate'] is Timestamp ? data['startDate'] as Timestamp : null;
            Timestamp? e = data['endDate'] is Timestamp ? data['endDate'] as Timestamp : null;
            return {
              'id': doc.id,
              'title': data['title'] ?? '',
              'startDate': s?.toDate() ?? DateTime.now(),
              'endDate': e?.toDate() ?? DateTime.now().add(const Duration(days: 7)),
            };
          }).toList();
        });
      }
    } catch (e) {
      // avoid calling setState inside catch without mounted
      print('Error loading projects: $e');
    }
  }

  Future<void> _loadTasks() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        final querySnapshot = await _firestore
            .collection('tasks')
            .where('userId', isEqualTo: user.uid)
            .get();

        if (!mounted) return; // <<< safety check
        setState(() {
          _tasks = querySnapshot.docs.map((doc) {
            final data = doc.data();
            Timestamp? d = data['dueDate'] is Timestamp ? data['dueDate'] as Timestamp : null;
            return {
              'id': doc.id,
              'projectId': data['projectId'],
              'title': data['title'] ?? '',
              'description': data['description'] ?? '',
              'dueDate': d?.toDate() ?? DateTime.now().add(const Duration(days: 1)),
              'completed': data['completed'] ?? false,
            };
          }).toList();
        });
      }
    } catch (e) {
      print('Error loading tasks: $e');
    }
  }

  Future<void> _addProject(Map<String, dynamic> project) async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        await _firestore.collection('projects').add({
          'title': project['title'],
          'startDate': Timestamp.fromDate(project['startDate']),
          'endDate': Timestamp.fromDate(project['endDate']),
          'userId': user.uid,
          'createdAt': Timestamp.now(),
        });
        // reload after add
        if (!mounted) return;
        await _loadProjects();
      }
    } catch (e) {
      print('Error adding project: $e');
    }
  }

  Future<void> _addTask(Map<String, dynamic> task) async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        await _firestore.collection('tasks').add({
          'projectId': task['projectId'],
          'title': task['title'],
          'description': task['description'],
          'dueDate': Timestamp.fromDate(task['dueDate']),
          'completed': task['completed'],
          'userId': user.uid,
          'createdAt': Timestamp.now(),
        });
        if (!mounted) return;
        await _loadTasks();
      }
    } catch (e) {
      print('Error adding task: $e');
    }
  }

  Future<void> _updateTask(String taskId, Map<String, dynamic> updates) async {
    try {
      await _firestore.collection('tasks').doc(taskId).update(updates);
      if (!mounted) return;
      await _loadTasks();
    } catch (e) {
      print('Error updating task: $e');
    }
  }

  Future<void> _deleteTask(String taskId) async {
    try {
      await _firestore.collection('tasks').doc(taskId).delete();
      if (!mounted) return;
      await _loadTasks();
    } catch (e) {
      print('Error deleting task: $e');
    }
  }

  Future<void> _deleteProject(String projectId) async {
    try {
      // First delete all tasks associated with this project
      final tasksQuery = await _firestore
          .collection('tasks')
          .where('projectId', isEqualTo: projectId)
          .get();

      for (var doc in tasksQuery.docs) {
        await doc.reference.delete();
      }

      // Then delete the project
      await _firestore.collection('projects').doc(projectId).delete();
      
      if (!mounted) return;
      await _loadProjects(); // Reload projects after deleting
      if (!mounted) return;
      await _loadTasks(); // Reload tasks after deleting
    } catch (e) {
      print('Error deleting project: $e');
    }
  }

  void _showAddOptionsDialog() {
    final theme = Theme.of(context);
    final bool isDarkMode = theme.brightness == Brightness.dark;
    final cardColor = theme.cardColor;
    final textColor = theme.textTheme.bodyLarge?.color;
    
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: cardColor,
          title: Text('Add New', style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.folder, color: isDarkMode ? const Color.fromRGBO(180, 100, 100, 1) : const Color(0xFFE07C7C)),
                title: Text('Create New Project', style: TextStyle(color: textColor)),
                onTap: () {
                  Navigator.pop(context);
                  _showAddProjectDialog();
                },
              ),
              ListTile(
                leading: Icon(Icons.task, color: isDarkMode ? const Color.fromRGBO(180, 100, 100, 1) : const Color(0xFFE07C7C)),
                title: Text('Add New Task', style: TextStyle(color: textColor)),
                onTap: () {
                  Navigator.pop(context);
                  _showAddTaskDialog();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showAddProjectDialog() {
    final theme = Theme.of(context);
    final bool isDarkMode = theme.brightness == Brightness.dark;
    final cardColor = theme.cardColor;
    final textColor = theme.textTheme.bodyLarge?.color;
    final hintColor = theme.hintColor;
    
    // Reset form fields
    _projectTitleController.clear();
    _projectStartDate = DateTime.now();
    _projectEndDate = DateTime.now().add(const Duration(days: 7));

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: cardColor,
              title: Text('Create New Project', style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: _projectTitleController,
                      style: TextStyle(color: textColor),
                      decoration: InputDecoration(
                        labelText: 'Project Title *',
                        labelStyle: TextStyle(color: hintColor),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: isDarkMode ? Colors.grey[800] : Colors.grey[50],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Start and end date selection
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () async {
                              final DateTime? pickedDate = await showDatePicker(
                                context: context,
                                initialDate: _projectStartDate,
                                firstDate: DateTime(2000),
                                lastDate: DateTime(2100),
                              );
                              if (pickedDate != null) {
                                setState(() {
                                  _projectStartDate = pickedDate;
                                });
                              }
                            },
                            style: OutlinedButton.styleFrom(
                              backgroundColor: isDarkMode ? Colors.grey[800] : Colors.grey[50],
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              side: BorderSide(color: isDarkMode ? Colors.grey[600]! : Colors.grey[300]!),
                            ),
                            child: Text(
                              'Start: ${DateFormat('MMM d, yyyy').format(_projectStartDate)}',
                              style: TextStyle(fontSize: 14, color: textColor),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () async {
                              final DateTime? pickedDate = await showDatePicker(
                                context: context,
                                initialDate: _projectEndDate,
                                firstDate: DateTime(2000),
                                lastDate: DateTime(2100),
                              );
                              if (pickedDate != null) {
                                setState(() {
                                  _projectEndDate = pickedDate;
                                });
                              }
                            },
                            style: OutlinedButton.styleFrom(
                              backgroundColor: isDarkMode ? Colors.grey[800] : Colors.grey[50],
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              side: BorderSide(color: isDarkMode ? Colors.grey[600]! : Colors.grey[300]!),
                            ),
                            child: Text(
                              'End: ${DateFormat('MMM d, yyyy').format(_projectEndDate)}',
                              style: TextStyle(fontSize: 14, color: textColor),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cancel', style: TextStyle(color: textColor)),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (_projectTitleController.text.isNotEmpty) {
                      // Create new project
                      final newProject = {
                        'title': _projectTitleController.text,
                        'startDate': _projectStartDate,
                        'endDate': _projectEndDate,
                      };

                      // Add to Firebase
                      _addProject(newProject);

                      Navigator.pop(context);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDarkMode ? const Color.fromRGBO(180, 100, 100, 1) : const Color(0xFFE07C7C),
                  ),
                  child: const Text('Create Project', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showAddTaskDialog() {
    final theme = Theme.of(context);
    final bool isDarkMode = theme.brightness == Brightness.dark;
    final cardColor = theme.cardColor;
    final textColor = theme.textTheme.bodyLarge?.color;
    final hintColor = theme.hintColor;
    
    if (_projects.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please create a project first'),
          backgroundColor: Color(0xFFE07C7C),
        ),
      );
      return;
    }

    // Reset form fields
    _taskTitleController.clear();
    _taskDescriptionController.clear();
    _taskDueDate = DateTime.now().add(const Duration(days: 1));

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: cardColor,
              title: Text('Add New Task', style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Project selection
                    DropdownButtonFormField(
                      value: _selectedProject?['id'] ?? _projects.first['id'],
                      dropdownColor: isDarkMode ? Colors.grey[800] : Colors.white,
                      style: TextStyle(color: textColor),
                      items: _projects.map((project) {
                        return DropdownMenuItem(
                          value: project['id'],
                          child: Text(project['title'], style: TextStyle(color: textColor)),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedProject = _projects.firstWhere((project) => project['id'] == value);
                        });
                      },
                      decoration: InputDecoration(
                        labelText: 'Project *',
                        labelStyle: TextStyle(color: hintColor),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: isDarkMode ? Colors.grey[800] : Colors.grey[50],
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _taskTitleController,
                      style: TextStyle(color: textColor),
                      decoration: InputDecoration(
                        labelText: 'Task Title *',
                        labelStyle: TextStyle(color: hintColor),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: isDarkMode ? Colors.grey[800] : Colors.grey[50],
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _taskDescriptionController,
                      style: TextStyle(color: textColor),
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: 'Description (optional)',
                        labelStyle: TextStyle(color: hintColor),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: isDarkMode ? Colors.grey[800] : Colors.grey[50],
                      ),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton(
                      onPressed: () async {
                        final DateTime? pickedDate = await showDatePicker(
                          context: context,
                          initialDate: _taskDueDate,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (pickedDate != null) {
                          setState(() {
                            _taskDueDate = pickedDate;
                          });
                        }
                      },
                      style: OutlinedButton.styleFrom(
                        backgroundColor: isDarkMode ? Colors.grey[800] : Colors.grey[50],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        side: BorderSide(color: isDarkMode ? Colors.grey[600]! : Colors.grey[300]!),
                      ),
                      child: Text(
                        'Due Date: ${DateFormat('MMM d, yyyy').format(_taskDueDate)}',
                        style: TextStyle(fontSize: 14, color: textColor),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cancel', style: TextStyle(color: textColor)),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (_taskTitleController.text.isNotEmpty) {
                      // Create new task
                      final newTask = {
                        'projectId': _selectedProject?['id'] ?? _projects.first['id'],
                        'title': _taskTitleController.text,
                        'description': _taskDescriptionController.text,
                        'dueDate': _taskDueDate,
                        'completed': false,
                      };

                      // Add to Firebase
                      _addTask(newTask);

                      Navigator.pop(context);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDarkMode ? const Color.fromRGBO(180, 100, 100, 1) : const Color(0xFFE07C7C),
                  ),
                  child: const Text('Add Task', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showEditTaskDialog(Map<String, dynamic> task) {
    final theme = Theme.of(context);
    final bool isDarkMode = theme.brightness == Brightness.dark;
    final cardColor = theme.cardColor;
    final textColor = theme.textTheme.bodyLarge?.color;
    final hintColor = theme.hintColor;
    
    // Set form fields with existing task data
    _taskTitleController.text = task['title'];
    _taskDescriptionController.text = task['description'] ?? '';
    _taskDueDate = task['dueDate'];
    _selectedProject = _projects.firstWhere((project) => project['id'] == task['projectId']);

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: cardColor,
              title: Text('Edit Task', style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Project selection
                    DropdownButtonFormField(
                      value: _selectedProject?['id'],
                      dropdownColor: isDarkMode ? Colors.grey[800] : Colors.white,
                      style: TextStyle(color: textColor),
                      items: _projects.map((project) {
                        return DropdownMenuItem(
                          value: project['id'],
                          child: Text(project['title'], style: TextStyle(color: textColor)),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedProject = _projects.firstWhere((project) => project['id'] == value);
                        });
                      },
                      decoration: InputDecoration(
                        labelText: 'Project *',
                        labelStyle: TextStyle(color: hintColor),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: isDarkMode ? Colors.grey[800] : Colors.grey[50],
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _taskTitleController,
                      style: TextStyle(color: textColor),
                      decoration: InputDecoration(
                        labelText: 'Task Title *',
                        labelStyle: TextStyle(color: hintColor),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: isDarkMode ? Colors.grey[800] : Colors.grey[50],
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _taskDescriptionController,
                      style: TextStyle(color: textColor),
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: 'Description (optional)',
                        labelStyle: TextStyle(color: hintColor),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: isDarkMode ? Colors.grey[800] : Colors.grey[50],
                      ),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton(
                      onPressed: () async {
                        final DateTime? pickedDate = await showDatePicker(
                          context: context,
                          initialDate: _taskDueDate,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (pickedDate != null) {
                          setState(() {
                            _taskDueDate = pickedDate;
                          });
                        }
                      },
                      style: OutlinedButton.styleFrom(
                        backgroundColor: isDarkMode ? Colors.grey[800] : Colors.grey[50],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        side: BorderSide(color: isDarkMode ? Colors.grey[600]! : Colors.grey[300]!),
                      ),
                      child: Text(
                        'Due Date: ${DateFormat('MMM d, yyyy').format(_taskDueDate)}',
                        style: TextStyle(fontSize: 14, color: textColor),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    _confirmDeleteTask(task['id']);
                    Navigator.pop(context);
                  },
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  child: const Text('Delete'),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cancel', style: TextStyle(color: textColor)),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (_taskTitleController.text.isNotEmpty) {
                      // Update task in Firebase
                      _updateTask(task['id'], {
                        'title': _taskTitleController.text,
                        'description': _taskDescriptionController.text,
                        'dueDate': Timestamp.fromDate(_taskDueDate),
                        'projectId': _selectedProject?['id'],
                      });

                      Navigator.pop(context);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDarkMode ? const Color.fromRGBO(180, 100, 100, 1) : const Color(0xFFE07C7C),
                  ),
                  child: const Text('Save Changes', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _confirmDeleteTask(String taskId) {
    final theme = Theme.of(context);
    final bool isDarkMode = theme.brightness == Brightness.dark;
    final cardColor = theme.cardColor;
    final textColor = theme.textTheme.bodyLarge?.color;
    
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: cardColor,
          title: Text('Delete Task', style: TextStyle(color: textColor)),
          content: Text('Are you sure you want to delete this task?', style: TextStyle(color: textColor)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: TextStyle(color: textColor)),
            ),
            ElevatedButton(
              onPressed: () {
                _deleteTask(taskId);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Delete', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  void _confirmDeleteProject(String projectId) {
    final theme = Theme.of(context);
    final bool isDarkMode = theme.brightness == Brightness.dark;
    final cardColor = theme.cardColor;
    final textColor = theme.textTheme.bodyLarge?.color;
    
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: cardColor,
          title: Text('Delete Project', style: TextStyle(color: textColor)),
          content: Text('Are you sure you want to delete this project? All tasks in this project will also be deleted.', style: TextStyle(color: textColor)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: TextStyle(color: textColor)),
            ),
            ElevatedButton(
              onPressed: () {
                _deleteProject(projectId);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Delete', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  void _selectProject(Map<String, dynamic> project) {
    if (!mounted) return;
    setState(() {
      _selectedProject = project;
    });
  }

  void _clearSelection() {
    if (!mounted) return;
    setState(() {
      _selectedProject = null;
    });
  }

  List<Map<String, dynamic>> _getTasksForProject(String projectId) {
    return _tasks.where((task) => task['projectId'] == projectId).toList();
  }

  List<Map<String, dynamic>> _getIncompleteTasksForProject(String projectId) {
    return _tasks.where((task) => task['projectId'] == projectId && !task['completed']).toList();
  }

  List<Map<String, dynamic>> _getCompletedTasksForProject(String projectId) {
    return _tasks.where((task) => task['projectId'] == projectId && task['completed']).toList();
  }

  int _getCompletedTaskCount(String projectId) {
    return _getTasksForProject(projectId).where((task) => task['completed']).length;
  }

  int _getTotalTaskCount(String projectId) {
    return _getTasksForProject(projectId).length;
  }

  void _toggleTaskCompletion(Map<String, dynamic> task) {
    // no direct setState here: update via backend and reload tasks
    _updateTask(task['id'], {
      'completed': !task['completed'],
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool isDarkMode = theme.brightness == Brightness.dark;
    final scaffoldBackground = theme.scaffoldBackgroundColor;
    final cardColor = theme.cardColor;
    final textColor = theme.textTheme.bodyLarge?.color;
    final hintColor = theme.hintColor;
    
    // Colors that adapt to theme
    final primaryColor = isDarkMode 
        ? const Color.fromRGBO(180, 100, 100, 1) // Darker pink for dark mode
        : const Color(0xFFE07C7C);

    return Scaffold(
      backgroundColor: scaffoldBackground,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Projects section (always shown)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Projects',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
          ),
          
          // Projects list
          SizedBox(
            height: 140,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _projects.length,
              itemBuilder: (context, index) {
                final project = _projects[index];
                final startDate = DateFormat('d MMM').format(project['startDate']);
                final endDate = DateFormat('d MMM').format(project['endDate']);
                final completedTasks = _getCompletedTaskCount(project['id']);
                final totalTasks = _getTotalTaskCount(project['id']);
                final progress = totalTasks > 0 ? completedTasks / totalTasks : 0;
                final isSelected = _selectedProject != null && _selectedProject!['id'] == project['id'];
                
                return GestureDetector(
                  onTap: () => _selectProject(project),
                  child: Container(
                    width: 200,
                    margin: const EdgeInsets.only(right: 16),
                    decoration: BoxDecoration(
                      gradient: isSelected 
                          ? LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                primaryColor.withOpacity(0.3),
                                primaryColor.withOpacity(0.1),
                              ],
                            )
                          : null,
                      color: isSelected ? null : cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: isSelected 
                          ? Border.all(color: primaryColor, width: 2)
                          : Border.all(color: isDarkMode ? Colors.grey[700]! : Colors.grey.shade200, width: 1),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(isDarkMode ? 0.1 : 0.15),
                          spreadRadius: 1,
                          blurRadius: 6,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // Project title with icon
                              Row(
                                children: [
                                  Icon(
                                    Icons.folder,
                                    color: isSelected ? primaryColor : (isDarkMode ? Colors.grey[400] : Colors.grey),
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      project['title'],
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: isSelected ? primaryColor : textColor,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              
                              // Date range
                              Row(
                                children: [
                                  Icon(Icons.calendar_today, size: 12, color: isDarkMode ? Colors.grey[400] : Colors.grey[600]),
                                  const SizedBox(width: 4),
                                  Text(
                                    '$startDate - $endDate',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                              
                              // Progress section
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Progress text
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Progress',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                                        ),
                                      ),
                                      Text(
                                        '${(progress * 100).toInt()}%',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: isSelected ? primaryColor : textColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  
                                  // Progress bar
                                  LinearProgressIndicator(
                                    value: progress.toDouble(),
                                    backgroundColor: isDarkMode ? Colors.grey[700] : Colors.grey[300],
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      progress == 1 
                                        ? Colors.green 
                                        : primaryColor,
                                    ),
                                    minHeight: 6,
                                  ),
                                  const SizedBox(height: 4),
                                  
                                  // Completed tasks count
                                  Text(
                                    '$completedTasks/$totalTasks tasks completed',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        
                        // Delete button
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: isDarkMode ? Colors.grey[700] : Colors.grey.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              icon: Icon(Icons.close, size: 14, color: isDarkMode ? Colors.grey[300] : Colors.grey[700]),
                              onPressed: () => _confirmDeleteProject(project['id']),
                              padding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // Task List section (shown when a project is selected)
          if (_selectedProject != null) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _selectedProject!['title'],
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  Text(
                    '${_getCompletedTaskCount(_selectedProject!['id'])}/${_getTotalTaskCount(_selectedProject!['id'])} completed',
                    style: TextStyle(
                      fontSize: 14,
                      color: hintColor,
                    ),
                  ),
                ],
              ),
            ),
            
            Divider(height: 1, color: isDarkMode ? Colors.grey[700] : Colors.grey[200]),
            
            Expanded(
              child: _getTasksForProject(_selectedProject!['id']).isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.task, size: 64, color: isDarkMode ? Colors.grey[600] : Colors.grey[300]),
                          const SizedBox(height: 16),
                          Text(
                            'No tasks yet',
                            style: TextStyle(
                              fontSize: 18,
                              color: hintColor,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Tap + to add your first task',
                            style: TextStyle(
                              fontSize: 14,
                              color: hintColor,
                            ),
                          ),
                        ],
                      ),
                    )
                  : SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Incomplete Tasks Section
                          if (_getIncompleteTasksForProject(_selectedProject!['id']).isNotEmpty) ...[
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                              child: Text(
                                'Incomplete Tasks',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: primaryColor,
                                ),
                              ),
                            ),
                            ..._getIncompleteTasksForProject(_selectedProject!['id']).map((task) {
                              final dueDate = DateFormat('MMM d, yyyy').format(task['dueDate']);
                              return _buildTaskItem(task, dueDate, isDarkMode, primaryColor, cardColor, textColor, hintColor);
                            }).toList(),
                          ],
                          
                          // Completed Tasks Section
                          if (_getCompletedTasksForProject(_selectedProject!['id']).isNotEmpty) ...[
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                              child: Text(
                                'Completed Tasks',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
                              ),
                            ),
                            ..._getCompletedTasksForProject(_selectedProject!['id']).map((task) {
                              final dueDate = DateFormat('MMM d, yyyy').format(task['dueDate']);
                              return _buildTaskItem(task, dueDate, isDarkMode, primaryColor, cardColor, textColor, hintColor);
                            }).toList(),
                          ],
                        ],
                      ),
                    ),
            ),
          ] else if (_projects.isNotEmpty) ...[
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.folder_open, size: 64, color: hintColor),
                    const SizedBox(height: 16),
                    Text(
                      'Select a project to view its tasks',
                      style: TextStyle(
                        fontSize: 16,
                        color: hintColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_task, size: 64, color: hintColor),
                    const SizedBox(height: 16),
                    Text(
                      'No projects yet',
                      style: TextStyle(
                        fontSize: 18,
                        color: hintColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tap + to create your first project',
                      style: TextStyle(
                        fontSize: 14,
                        color: hintColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddOptionsDialog,
        backgroundColor: primaryColor,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildTaskItem(Map<String, dynamic> task, String dueDate, bool isDarkMode, Color primaryColor, Color cardColor, Color? textColor, Color? hintColor) {
    return Dismissible(
      key: Key(task['id'].toString()),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (direction) async {
        // Show confirmation dialog before deleting
        if (!mounted) return false;
        return await showDialog(
          context: context,
          builder: (BuildContext context) {
            final theme = Theme.of(context);
            final isDarkMode = theme.brightness == Brightness.dark;
            final cardColor = theme.cardColor;
            final textColor = theme.textTheme.bodyLarge?.color;
            
            return AlertDialog(
              backgroundColor: cardColor,
              title: Text('Confirm Delete', style: TextStyle(color: textColor)),
              content: Text('Are you sure you want to delete this task?', style: TextStyle(color: textColor)),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text('Cancel', style: TextStyle(color: textColor)),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  child: const Text('Delete', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
      onDismissed: (direction) {
        _deleteTask(task['id']);
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: task['completed'] 
                ? (isDarkMode ? Colors.green.shade700 : Colors.green.shade100) 
                : (isDarkMode ? Colors.grey[700]! : Colors.grey.shade200),
            width: task['completed'] ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(isDarkMode ? 0.05 : 0.1),
              spreadRadius: 1,
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          children: [
            Checkbox(
              value: task['completed'],
              onChanged: (value) {
                _toggleTaskCompletion(task);
              },
              activeColor: primaryColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task['title'],
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: task['completed'] 
                          ? hintColor 
                          : textColor,
                    ),
                  ),
                  if (task['description'] != null && task['description'].isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        task['description'],
                        style: TextStyle(
                          fontSize: 14,
                          color: hintColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: 12,
                          color: task['completed'] 
                              ? hintColor 
                              : primaryColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Due: $dueDate',
                          style: TextStyle(
                            fontSize: 12,
                            color: task['completed'] 
                                ? hintColor 
                                : primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(Icons.edit, size: 20, color: hintColor),
              onPressed: () => _showEditTaskDialog(task),
            ),
          ],
        ),
      ),
    );
  }
}