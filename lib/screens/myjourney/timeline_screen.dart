import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:onboardx_tnb_app/l10n/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:onboardx_tnb_app/services/supabase_service.dart';

class TimelineScreen extends StatefulWidget {
  const TimelineScreen({super.key});

  @override
  State<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends State<TimelineScreen> {
  DateTime _currentDate = DateTime.now();
  late List<DateTime> _visibleDays;
  DateTime? _selectedDate;
  final ScrollController _scrollController = ScrollController();

  final SupabaseService _supabaseService = SupabaseService();
  User? _currentUser;
  List<Map<String, dynamic>> _events = [];
  StreamSubscription<List<Map<String, dynamic>>>? _eventsSubscription;
  StreamSubscription<User?>? _authSubscription;
  
  // New variables for user data and welcome section
  Map<String, dynamic>? _userData;
  bool _showWelcome = false;
  SharedPreferences? _prefs;

  // Loading and refresh states
  bool _isLoading = false;
  bool _isAddingEvent = false;
  final GlobalKey<RefreshIndicatorState> _refreshIndicatorKey = GlobalKey<RefreshIndicatorState>();

  // Controllers for the add event form
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _startTimeController = TextEditingController();
  final TextEditingController _endTimeController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _linkController = TextEditingController();
  DateTime _newEventDate = DateTime.now();
  TimeOfDay _newEventStartTime = TimeOfDay.now();
  TimeOfDay _newEventEndTime = TimeOfDay(hour: TimeOfDay.now().hour + 1, minute: TimeOfDay.now().minute);

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _generateVisibleDays();

    // Listen to auth changes - start listener only when user is logged in
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) {
      _currentUser = user;
      if (_currentUser != null) {
        _setupEventsListener();
        _fetchUserData();
        _initPreferencesForUser(_currentUser!.uid);
      } else {
        _eventsSubscription?.cancel();
        _eventsSubscription = null;
        if (mounted) {
          setState(() {
            _events = [];
            _userData = null;
            _showWelcome = false;
          });
        }
      }
    });

    // Scroll to current date after initial build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToCurrentDate();
    });
  }

  /// Initialize per-user preference for showing the welcome section.
  /// Key used: 'hasSeenTimelineWelcome_<uid>'
  Future<void> _initPreferencesForUser(String uid) async {
    try {
      _prefs ??= await SharedPreferences.getInstance();
      final key = 'hasSeenTimelineWelcome_$uid';
      final bool hasSeenWelcome = _prefs?.getBool(key) ?? false;

      if (!hasSeenWelcome) {
        if (mounted) {
          setState(() {
            _showWelcome = true;
          });
        }
        // Persist that this user has now seen the welcome section
        await _prefs?.setBool(key, true);
      } else {
        if (mounted) {
          setState(() {
            _showWelcome = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error initializing preferences for user $uid: $e');
      // don't crash the UI; default to not showing if something goes wrong
      if (mounted) {
        setState(() {
          _showWelcome = false;
        });
      }
    }
  }

  Future<void> _fetchUserData() async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Use SupabaseService to get user data
        final userData = await _supabaseService.getUserProfileForApp(user.uid);

        if (!mounted) return;
        if (userData != null) {
          setState(() {
            _userData = userData;
          });
        }
      }
    } catch (e) {
      print("Error fetching user data: $e");
    }
  }

  @override
  void dispose() {
    _eventsSubscription?.cancel();
    _authSubscription?.cancel();
    _scrollController.dispose();
    _titleController.dispose();
    _startTimeController.dispose();
    _endTimeController.dispose();
    _locationController.dispose();
    _descriptionController.dispose();
    _linkController.dispose();
    super.dispose();
  }

  void _setupEventsListener() {
    // cancel existing subscription
    _eventsSubscription?.cancel();

    if (_currentUser == null) return;

    try {
      // Use polling stream for more reliable updates
      final stream = _supabaseService.getEventsStreamWithPolling(_currentUser!.uid);

      _eventsSubscription = stream.listen((List<Map<String, dynamic>> events) {
        _processEvents(events);
      }, onError: (error) {
        debugPrint('Error in events stream: $error');
        // Fallback to manual refresh if stream error
        _refreshEvents();
      });
    } catch (e) {
      debugPrint('Failed to start events listener: $e');
      // Fallback to manual refresh
      _refreshEvents();
    }
  }

  // Manual refresh method
  Future<void> _refreshEvents() async {
    if (_currentUser == null) return;

    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    try {
      final events = await _supabaseService.getEvents(_currentUser!.uid);
      _processEvents(events);
      
      debugPrint('✅ Manually refreshed ${events.length} events');
    } catch (e) {
      debugPrint('Error manually refreshing events: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error refreshing events: $e')),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Process events data
  void _processEvents(List<Map<String, dynamic>> events) {
    final List<Map<String, dynamic>> loaded = events.map((event) {
      final rawDate = event['date'];
      final DateTime eventDate = _parseEventDate(rawDate);

      return {
        'id': event['id'],
        'title': event['title'] ?? '',
        'startTime': event['start_time'] ?? '',
        'endTime': event['end_time'] ?? event['em_time'] ?? '',
        'location': event['location'] ?? '',
        'description': event['description'] ?? '',
        'link': event['link'] ?? '',
        'date': eventDate,
      };
    }).toList();

    // sort by date/time
    loaded.sort((a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime));

    if (!mounted) return;
    setState(() {
      _events = loaded;
    });

    debugPrint('🔄 Processed ${loaded.length} events');
  }

  DateTime _parseEventDate(dynamic raw) {
    if (raw == null) return DateTime.now();

    // Supabase returns DateTime directly
    if (raw is DateTime) {
      return raw;
    }

    // If string - try parsing
    if (raw is String) {
      final parsed = DateTime.tryParse(raw);
      return parsed ?? DateTime.now();
    }

    // Unknown type -> fallback
    return DateTime.now();
  }

  void _generateVisibleDays() {
    // Generate days for the current month
    final firstDay = DateTime(_currentDate.year, _currentDate.month, 1);
    final lastDay = DateTime(_currentDate.year, _currentDate.month + 1, 0);

    _visibleDays = [];
    for (int i = 0; i < lastDay.day; i++) {
      _visibleDays.add(DateTime(_currentDate.year, _currentDate.month, i + 1));
    }
  }

  void _scrollToCurrentDate() {
    if (_currentDate.month == DateTime.now().month && _currentDate.year == DateTime.now().year) {
      final currentDateIndex = _visibleDays.indexWhere((date) =>
          date.day == DateTime.now().day &&
          date.month == DateTime.now().month &&
          date.year == DateTime.now().year);

      if (currentDateIndex != -1) {
        final double scrollPosition = currentDateIndex * 70.0;
        _scrollController.animateTo(
          scrollPosition,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    }
  }

  void _goToPreviousMonth() {
    if (!mounted) return;
    setState(() {
      _currentDate = DateTime(_currentDate.year, _currentDate.month - 1, 1);
      _generateVisibleDays();
      _selectedDate = DateTime(_currentDate.year, _currentDate.month, 1);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollController.jumpTo(0);
      });
    });
  }

  void _goToNextMonth() {
    if (!mounted) return;
    setState(() {
      _currentDate = DateTime(_currentDate.year, _currentDate.month + 1, 1);
      _generateVisibleDays();
      _selectedDate = DateTime(_currentDate.year, _currentDate.month, 1);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollController.jumpTo(0);
      });
    });
  }

  void _showMonthYearPicker() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
        
        return AlertDialog(
          backgroundColor: isDarkMode ? Colors.grey[900] : Colors.white,
          title: Text('Select Month and Year', style: TextStyle(color: isDarkMode ? Colors.white : Colors.black)),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Year selector
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: Icon(Icons.arrow_back_ios, color: isDarkMode ? Colors.white : Colors.black),
                      onPressed: () {
                        if (!mounted) return;
                        setState(() {
                          _currentDate = DateTime(_currentDate.year - 1, _currentDate.month, 1);
                        });
                      },
                    ),
                    Text(
                      _currentDate.year.toString(),
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : Colors.black),
                    ),
                    IconButton(
                      icon: Icon(Icons.arrow_forward_ios, color: isDarkMode ? Colors.white : Colors.black),
                      onPressed: () {
                        if (!mounted) return;
                        setState(() {
                          _currentDate = DateTime(_currentDate.year + 1, _currentDate.month, 1);
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Month grid
                GridView.builder(
                  shrinkWrap: true,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    childAspectRatio: 1.5,
                  ),
                  itemCount: 12,
                  itemBuilder: (context, index) {
                    final month = index + 1;
                    final monthName = DateFormat('MMM').format(DateTime(2023, month, 1));
                    final isCurrentMonth = month == _currentDate.month;

                    return InkWell(
                      onTap: () {
                        if (!mounted) return;
                        setState(() {
                          _currentDate = DateTime(_currentDate.year, month, 1);
                          _generateVisibleDays();
                          _selectedDate = DateTime(_currentDate.year, _currentDate.month, 1);
                          Navigator.pop(context);
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            _scrollController.jumpTo(0);
                          });
                        });
                      },
                      child: Container(
                        margin: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: isCurrentMonth ? Colors.blue : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isCurrentMonth ? Colors.blue : (isDarkMode ? Colors.grey[700]! : Colors.grey[300]!),
                          ),
                        ),
                        child: Center(
                          child: Text(
                            monthName,
                            style: TextStyle(
                              color: isCurrentMonth ? Colors.white : (isDarkMode ? Colors.white : Colors.black),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showAddEventDialog() {
    // Reset form fields
    _titleController.clear();
    _startTimeController.text = DateFormat('h:mm a').format(DateTime.now());
    _endTimeController.text = DateFormat('h:mm a').format(DateTime.now().add(const Duration(hours: 1)));
    _locationController.clear();
    _descriptionController.clear();
    _linkController.clear();
    _newEventDate = _selectedDate ?? DateTime.now();
    _newEventStartTime = TimeOfDay.now();
    _newEventEndTime = TimeOfDay(hour: TimeOfDay.now().hour + 1, minute: TimeOfDay.now().minute);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
        
        return StatefulBuilder(builder: (context, setState) {
          return AlertDialog(
            backgroundColor: isDarkMode ? Colors.grey[900] : Colors.white,
            title: Text((AppLocalizations.of(context)!.addNewEvent), style: TextStyle(color: isDarkMode ? Colors.white : Colors.black)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _titleController,
                    style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
                    decoration: InputDecoration(
                      labelText: (AppLocalizations.of(context)!.title),
                      labelStyle: TextStyle(color: isDarkMode ? Colors.grey[400] : Colors.grey[700]),
                      border: const OutlineInputBorder(),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: isDarkMode ? Colors.grey[700]! : Colors.grey[300]!),
                      ),
                      focusedBorder: const OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.blue),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Date selection
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () async {
                            final DateTime? pickedDate = await showDatePicker(
                              context: context,
                              initialDate: _newEventDate,
                              firstDate: DateTime(2000),
                              lastDate: DateTime(2100),
                            );
                            if (pickedDate != null) {
                              setState(() {
                                _newEventDate = pickedDate;
                              });
                            }
                          },
                          child: Text(
                            DateFormat('MMM d, yyyy').format(_newEventDate),
                            style: TextStyle(fontSize: 16, color: isDarkMode ? Colors.white : Colors.black),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Start and end time
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _startTimeController,
                          readOnly: true,
                          style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
                          decoration: InputDecoration(
                            labelText: (AppLocalizations.of(context)!.startTime),
                            labelStyle: TextStyle(color: isDarkMode ? Colors.grey[400] : Colors.grey[700]),
                            border: const OutlineInputBorder(),
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: isDarkMode ? Colors.grey[700]! : Colors.grey[300]!),
                            ),
                            focusedBorder: const OutlineInputBorder(
                              borderSide: BorderSide(color: Colors.blue),
                            ),
                          ),
                          onTap: () async {
                            final TimeOfDay? pickedTime = await showTimePicker(
                              context: context,
                              initialTime: _newEventStartTime,
                            );
                            if (pickedTime != null) {
                              setState(() {
                                _newEventStartTime = pickedTime;
                                _startTimeController.text = pickedTime.format(context);
                              });
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextField(
                          controller: _endTimeController,
                          readOnly: true,
                          style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
                          decoration: InputDecoration(
                            labelText: (AppLocalizations.of(context)!.endTime),
                            labelStyle: TextStyle(color: isDarkMode ? Colors.grey[400] : Colors.grey[700]),
                            border: const OutlineInputBorder(),
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: isDarkMode ? Colors.grey[700]! : Colors.grey[300]!),
                            ),
                            focusedBorder: const OutlineInputBorder(
                              borderSide: BorderSide(color: Colors.blue),
                            ),
                          ),
                          onTap: () async {
                            final TimeOfDay? pickedTime = await showTimePicker(
                              context: context,
                              initialTime: _newEventEndTime,
                            );
                            if (pickedTime != null) {
                              setState(() {
                                _newEventEndTime = pickedTime;
                                _endTimeController.text = pickedTime.format(context);
                              });
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _locationController,
                    style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
                    decoration: InputDecoration(
                      labelText: (AppLocalizations.of(context)!.locationoptional),
                      labelStyle: TextStyle(color: isDarkMode ? Colors.grey[400] : Colors.grey[700]),
                      border: const OutlineInputBorder(),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: isDarkMode ? Colors.grey[700]! : Colors.grey[300]!),
                      ),
                      focusedBorder: const OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.blue),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _descriptionController,
                    style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: (AppLocalizations.of(context)!.descriptionoptional),
                      labelStyle: TextStyle(color: isDarkMode ? Colors.grey[400] : Colors.grey[700]),
                      border: const OutlineInputBorder(),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: isDarkMode ? Colors.grey[700]! : Colors.grey[300]!),
                      ),
                      focusedBorder: const OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.blue),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _linkController,
                    style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
                    decoration: InputDecoration(
                      labelText: (AppLocalizations.of(context)!.linkoptional),
                      labelStyle: TextStyle(color: isDarkMode ? Colors.grey[400] : Colors.grey[700]),
                      hintText: 'https://example.com',
                      border: const OutlineInputBorder(),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: isDarkMode ? Colors.grey[700]! : Colors.grey[300]!),
                      ),
                      focusedBorder: const OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.blue),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: _isAddingEvent ? null : () => Navigator.pop(context), 
                child: Text((AppLocalizations.of(context)!.cancel), style: TextStyle(color: isDarkMode ? Colors.white : Colors.black))
              ),
              ElevatedButton(
                onPressed: _isAddingEvent ? null : () async {
                  if (_titleController.text.isNotEmpty && _currentUser != null) {
                    if (!mounted) return;
                    setState(() {
                      _isAddingEvent = true;
                    });

                    try {
                      final DateTime composedDateTime = DateTime(
                        _newEventDate.year,
                        _newEventDate.month,
                        _newEventDate.day,
                        _newEventStartTime.hour,
                        _newEventStartTime.minute,
                      );

                      // Save to Supabase
                      await _supabaseService.addEvent({
                        'title': _titleController.text,
                        'start_time': _startTimeController.text,
                        'end_time': _endTimeController.text,
                        'em_time': _endTimeController.text,
                        'location': _locationController.text,
                        'description': _descriptionController.text,
                        'link': _linkController.text,
                        'date': composedDateTime.toIso8601String(),
                        'user_id': _currentUser!.uid,
                      });

                      // FORCE REFRESH SETELAH ADD
                      await _refreshEvents();

                      if (!mounted) return;
                      Navigator.pop(context);
                      
                      // Tampilkan snackbar konfirmasi
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Event "${_titleController.text}" added successfully'),
                          duration: const Duration(seconds: 2),
                          backgroundColor: Colors.green,
                        ),
                      );

                    } catch (e) {
                      debugPrint('Error adding event: $e');
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Failed to add event: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    } finally {
                      if (!mounted) return;
                      setState(() {
                        _isAddingEvent = false;
                      });
                    }
                  } else {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Title required & must be logged in'),
                        backgroundColor: Colors.orange,
                      ),
                    );
                  }
                },
                child: _isAddingEvent 
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2, 
                          valueColor: AlwaysStoppedAnimation<Color>(isDarkMode ? Colors.white : Colors.black),
                        ),
                      )
                    : Text((AppLocalizations.of(context)!.addEvent)),
              ),
            ],
          );
        });
      },
    );
  }

  Future<void> _deleteEvent(String eventId) async {
    try {
      // Show loading
      if (!mounted) return;
      setState(() {
        _isLoading = true;
      });

      await _supabaseService.deleteEvent(eventId);
      
      // Refresh events after delete
      await _refreshEvents();
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Event deleted successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      debugPrint('Error deleting event: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete event: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _getDayAbbreviation(DateTime date) {
    return DateFormat('E').format(date).substring(0, 3);
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.day == now.day && date.month == now.month && date.year == now.year;
  }

  bool _hasEvents(DateTime date) {
    return _events.any((event) {
      final eventDate = event['date'] as DateTime;
      return eventDate.day == date.day && eventDate.month == date.month && eventDate.year == date.year;
    });
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not launch $url')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final formattedDate = DateFormat('MMM d, yyyy').format(_selectedDate!);

    // Get events for selected date and sort by time
    final eventsForSelectedDate = _events.where((event) {
      final eventDate = event['date'] as DateTime;
      return eventDate.day == _selectedDate!.day && eventDate.month == _selectedDate!.month && eventDate.year == _selectedDate!.year;
    }).toList();

    // Sort events by time (date contains time too)
    eventsForSelectedDate.sort((a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime));

    return Scaffold(
      backgroundColor: isDarkMode ? Colors.grey[900] : Colors.grey[100],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome section - only shown on first time (per user)
          if (_showWelcome)
            Container(
              color: isDarkMode ? Colors.grey[800] : Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                children: [
                  // Avatar
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: isDarkMode ? Colors.grey[700] : Colors.grey[200],
                    child: Icon(Icons.person, size: 40, color: isDarkMode ? Colors.grey[400] : Colors.grey),
                  ),
                  const SizedBox(width: 12),
                  // Welcome text with actual user data
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Welcome to TNB,', style: TextStyle(fontSize: 16, color: isDarkMode ? Colors.grey[400] : Colors.grey)),
                      const SizedBox(height: 4),
                      Text(
                        _userData?['username'] ?? 'User',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : Colors.black),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          const SizedBox(height: 16),

          // Month and year navigation
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: Icon(Icons.arrow_back_ios, color: isDarkMode ? Colors.white : Colors.black),
                  onPressed: _goToPreviousMonth
                ),
                GestureDetector(
                  onTap: _showMonthYearPicker, 
                  child: Text(
                    DateFormat('MMMM yyyy').format(_currentDate), 
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : Colors.black)
                  )
                ),
                IconButton(
                  icon: Icon(Icons.arrow_forward_ios, color: isDarkMode ? Colors.white : Colors.black),
                  onPressed: _goToNextMonth
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Horizontal scrollable days
          Container(
            height: 80,
            padding: const EdgeInsets.symmetric(vertical: 8),
            color: isDarkMode ? Colors.grey[900] : Colors.grey[100],
            child: ListView.builder(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              itemCount: _visibleDays.length,
              itemBuilder: (context, index) {
                final day = _visibleDays[index];
                final isToday = _isToday(day);
                final hasEvents = _hasEvents(day);
                final isSelected = _selectedDate != null && day.day == _selectedDate!.day && day.month == _selectedDate!.month && day.year == _selectedDate!.year;

                return GestureDetector(
                  onTap: () {
                    if (!mounted) return;
                    setState(() {
                      _selectedDate = day;
                    });
                  },
                  child: Container(
                    width: 70,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.blue : (isToday ? Colors.blue.withOpacity(0.1) : Colors.transparent),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: isToday ? Colors.blue : Colors.transparent, width: 1),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _getDayAbbreviation(day), 
                          style: TextStyle(fontSize: 12, color: isSelected ? Colors.white : (isDarkMode ? Colors.grey[400] : Colors.grey[700]))
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${day.day}', 
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isSelected ? Colors.white : (isDarkMode ? Colors.white : Colors.black))
                        ),
                        if (hasEvents)
                          Container(width: 6, height: 6, margin: const EdgeInsets.only(top: 4), decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // Selected date
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(formattedDate, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : Colors.black)),
              if (_isToday(_selectedDate!))
                Text((AppLocalizations.of(context)!.today), style: TextStyle(fontSize: 14, color: Colors.blue[700], fontWeight: FontWeight.bold)),
            ]),
          ),

          // Events list (Timeline) with RefreshIndicator
          Expanded(
            child: RefreshIndicator(
              key: _refreshIndicatorKey,
              onRefresh: _refreshEvents,
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _events.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.event_note, size: 64, color: isDarkMode ? Colors.grey[600] : Colors.grey[400]),
                              const SizedBox(height: 16),
                              Text(
                                'No events found',
                                style: TextStyle(color: isDarkMode ? Colors.grey[400] : Colors.grey[600]),
                              ),
                              const SizedBox(height: 8),
                              TextButton(
                                onPressed: _showAddEventDialog,
                                child: const Text('Add your first event'),
                              ),
                            ],
                          ),
                        )
                      : eventsForSelectedDate.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.calendar_today, size: 64, color: isDarkMode ? Colors.grey[600] : Colors.grey[400]),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No events on $formattedDate',
                                    style: TextStyle(color: isDarkMode ? Colors.grey[400] : Colors.grey[600]),
                                  ),
                                  const SizedBox(height: 8),
                                  TextButton(
                                    onPressed: _showAddEventDialog,
                                    child: const Text('Add event for this date'),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              itemCount: eventsForSelectedDate.length,
                              itemBuilder: (context, index) {
                                final event = eventsForSelectedDate[index];
                                final eventDate = event['date'] as DateTime;

                                return Dismissible(
                                  key: Key(event['id']),
                                  direction: DismissDirection.endToStart,
                                  background: Container(
                                    color: Colors.red,
                                    alignment: Alignment.centerRight,
                                    padding: const EdgeInsets.only(right: 20),
                                    child: const Icon(Icons.delete, color: Colors.white),
                                  ),
                                  onDismissed: (direction) {
                                    _deleteEvent(event['id']);
                                  },
                                  child: TimelineEventItem(
                                    title: event['title'],
                                    startTime: event['startTime'],
                                    endTime: event['endTime'],
                                    location: event['location'],
                                    description: event['description'],
                                    link: event['link'],
                                    onLinkTap: (link) {
                                      if (link.isNotEmpty) {
                                        _launchUrl(link);
                                      }
                                    },
                                    isDarkMode: isDarkMode,
                                  ),
                                );
                              },
                            ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _isAddingEvent ? null : _showAddEventDialog,
        backgroundColor: _isAddingEvent ? Colors.grey : const Color.fromRGBO(224, 124, 124, 1),
        child: _isAddingEvent 
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
              )
            : const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

class TimelineEventItem extends StatelessWidget {
  final String title;
  final String startTime;
  final String endTime;
  final String location;
  final String description;
  final String link;
  final Function(String) onLinkTap;
  final bool isDarkMode;

  const TimelineEventItem({
    super.key,
    required this.title,
    required this.startTime,
    required this.endTime,
    required this.location,
    required this.description,
    required this.link,
    required this.onLinkTap,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey[800] : Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(isDarkMode ? 0.1 : 0.2), spreadRadius: 1, blurRadius: 3, offset: const Offset(0, 1))],
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Time indicator
        Container(
          width: 80,
          padding: const EdgeInsets.only(right: 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(startTime, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue)),
            Text(endTime, style: TextStyle(fontSize: 14, color: isDarkMode ? Colors.grey[400] : Colors.grey[600])),
          ]),
        ),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : Colors.black)),
            if (location.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(location, style: TextStyle(color: isDarkMode ? Colors.grey[400] : Colors.grey[600], fontSize: 14)),
            ],
            if (description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(description, style: TextStyle(color: isDarkMode ? Colors.grey[400] : Colors.grey[600], fontSize: 14)),
            ],
            if (link.isNotEmpty) ...[
              const SizedBox(height: 8),
              GestureDetector(onTap: () => onLinkTap(link), child: Text(link, style: const TextStyle(color: Colors.blue, fontSize: 14, decoration: TextDecoration.underline), overflow: TextOverflow.ellipsis)),
            ],
          ]),
        ),
      ]),
    );
  }
}