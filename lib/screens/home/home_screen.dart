// home_screen.dart
import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:onboardx_tnb_app/screens/auth/login_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:onboardx_tnb_app/screens/buddychat/help_center_screen.dart';
import 'package:onboardx_tnb_app/screens/document/document_screen.dart';
import 'package:onboardx_tnb_app/screens/learninghub/learning_hub_screen.dart';
import 'package:onboardx_tnb_app/screens/meettheteam/meet_the_team_screen.dart';
import 'package:onboardx_tnb_app/screens/myjourney/appbar_my_journey.dart';
import 'package:onboardx_tnb_app/screens/myjourney/timeline_screen.dart';
import 'package:onboardx_tnb_app/screens/qrcodescanner/qr_code_scanner.dart';
import 'package:onboardx_tnb_app/screens/setting/setting_screen.dart';
import 'package:onboardx_tnb_app/screens/taskmanager/task_manager_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:onboardx_tnb_app/services/supabase_service.dart';
import 'package:onboardx_tnb_app/screens/setting/manage_your_account_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  Map<String, dynamic>? _userData;
  bool _isCheckingVerification = true;

  // Supabase integration
  final SupabaseService _supabaseService = SupabaseService();
  List<Map<String, dynamic>> _projects = [];

  // List of screens for each tab
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      const HomeContent(), // Home tab
      const ScanQrScreen(), // QR Code Scanner tab
      const SettingScreen(), // Settings tab
    ];

    _loadUserData();

    // Check email verification after UI is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkEmailVerification();
    });
  }

  void _onItemTapped(int index) {
    if (!mounted) return;
    setState(() {
      _selectedIndex = index;
    });
  }

  /// NOTE: Firebase used only for authentication. User profile is from Supabase.
  Future<void> _loadUserData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Get profile from Supabase (this includes profile_image and profile_image_url)
      Map<String, dynamic>? supabaseData;
      try {
        supabaseData = await _supabaseService.getUserProfile(user.uid);
      } catch (e) {
        print('Supabase get user profile failed in HomeScreen: $e');
      }

      // Debug: log what we received
      print('HomeScreen: supabaseData => $supabaseData');

      if (!mounted) return;

      final merged = <String, dynamic>{};

      // Map supabase fields (snake_case) -> camelCase expected in UI
      if (supabaseData != null) {
        merged.addAll(supabaseData);

        merged['fullName'] = supabaseData['full_name'] ??
            merged['fullName'] ??
            supabaseData['username'];
        merged['email'] = supabaseData['email'] ?? merged['email'];
        merged['phoneNumber'] =
            supabaseData['phone_number'] ?? merged['phoneNumber'];
        // Map work_type -> workType (important fix)
        merged['workType'] = supabaseData['work_type'] ??
            supabaseData['workType'] ??
            merged['workType'];
        merged['username'] = supabaseData['username'] ?? merged['username'];

        // profile image url already added by getUserProfile as 'profile_image_url'
        if (supabaseData['profile_image_url'] != null) {
          merged['profileImageUrl'] = supabaseData['profile_image_url'];
        } else if (supabaseData['profile_image'] != null) {
          try {
            merged['profileImageUrl'] = _supabaseService.getPublicUrl(
                'profile-images', supabaseData['profile_image']);
          } catch (e) {
            print('Error building public URL in HomeScreen: $e');
          }
        }
      }

      // If user has a team_id, fetch team details to get work_team & work_place
      try {
        final teamId = supabaseData?['team_id'];
        print('HomeScreen: teamId => $teamId');
        if (teamId != null) {
          final teamData =
              await _supabaseService.getTeamByNoTeam(teamId.toString());
          print('HomeScreen: teamData => $teamData');
          if (teamData != null) {
            merged['workTeam'] = teamData['work_team'] ?? merged['workTeam'];
            merged['workPlace'] = teamData['work_place'] ?? merged['workPlace'];
          }
        } else {
          // fallback if team info stored inside user row
          merged['workTeam'] = supabaseData?['work_team'] ??
              supabaseData?['work_unit'] ??
              merged['workTeam'];
          merged['workPlace'] =
              supabaseData?['work_place'] ?? merged['workPlace'];
        }
      } catch (e) {
        print('Error loading team info in HomeScreen: $e');
      }

      setState(() {
        _userData = merged;
      });

      print('Loaded user data in HomeScreen: $_userData');
    } catch (e) {
      print('Error loading user data in HomeScreen: $e');
    }
  }

  Future<void> _checkEmailVerification() async {
    try {
      User? user = FirebaseAuth.instance.currentUser;

      if (user != null && !user.emailVerified) {
        if (!mounted) return;
        _showVerificationDialog(context, user);
      }

      if (!mounted) return;
      setState(() {
        _isCheckingVerification = false;
      });
    } catch (e) {
      print('Error checking email verification: $e');
      if (!mounted) return;
      setState(() {
        _isCheckingVerification = false;
      });
    }
  }

  void _showVerificationDialog(BuildContext context, User user) {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Email Not Verified'),
          content: const Text(
              'Please verify your email address before using the app. '
              'Check your inbox for a verification email.'),
          actions: <Widget>[
            TextButton(
              child: const Text('Close'),
              onPressed: () {
                if (!mounted) return;
                Navigator.of(dialogContext).pop();
              },
            ),
            TextButton(
              child: const Text('Resend Verification'),
              onPressed: () async {
                try {
                  await user.sendEmailVerification();
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Verification email sent!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                  Navigator.of(dialogContext).pop();
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: ${e.toString()}'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
            ),
            TextButton(
              child: const Text('Logout'),
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                await _signOut();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _signOut() async {
    try {
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    } catch (e) {
      print('Error signing out: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool isDarkMode = theme.brightness == Brightness.dark;

    // Colors that adapt to theme
    final primaryColor = isDarkMode
        ? const Color.fromRGBO(180, 100, 100, 1) // Darker pink for dark mode
        : const Color.fromRGBO(224, 124, 124, 1);

    // Show loading indicator while checking verification
    if (_isCheckingVerification) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: Center(
          child: CircularProgressIndicator(
            color: primaryColor,
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: _screens[_selectedIndex],
      bottomNavigationBar: _buildBottomNavBar(primaryColor),
    );
  }

  // Bottom Navigation Bar
  Widget _buildBottomNavBar(Color primaryColor) {
    return CurvedNavigationBar(
      backgroundColor: Colors.transparent,
      color: primaryColor,
      buttonBackgroundColor: primaryColor,
      height: 60,
      items: const <Widget>[
        Icon(Icons.home, size: 30, color: Colors.white),
        Icon(Icons.qr_code_scanner, size: 30, color: Colors.white),
        Icon(Icons.settings, size: 30, color: Colors.white),
      ],
      index: _selectedIndex,
      onTap: _onItemTapped,
      letIndexChange: (index) => true,
    );
  }
}

// Home Content Widget (With Profile Image Support)
class HomeContent extends StatefulWidget {
  const HomeContent({super.key});

  @override
  State<HomeContent> createState() => _HomeContentState();
}

class _HomeContentState extends State<HomeContent> {
  bool _isHeaderExpanded = false;
  Map<String, dynamic>? _userData;
  Color? primaryColor;

  // Add SupabaseService
  final SupabaseService _supabaseService = SupabaseService();

  @override
  void initState() {
    super.initState();
    _loadUserData(); // Load data when widget initializes
  }

  // Combined function to load user data from Supabase only
  Future<void> _loadUserData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      Map<String, dynamic>? supabaseData;
      try {
        supabaseData = await _supabaseService.getUserProfile(user.uid);
      } catch (e) {
        print('Supabase get user failed in HomeContent: $e');
      }

      print('HomeContent: supabaseData => $supabaseData');

      if (!mounted) return;

      String? profileImageUrl;

      final merged = <String, dynamic>{};
      if (supabaseData != null) {
        merged.addAll(supabaseData);

        merged['fullName'] = supabaseData['full_name'] ?? merged['fullName'];
        merged['email'] = supabaseData['email'] ?? merged['email'];
        merged['phoneNumber'] =
            supabaseData['phone_number'] ?? merged['phoneNumber'];
        merged['username'] = supabaseData['username'] ?? merged['username'];
        // Map work_type -> workType (important fix)
        merged['workType'] = supabaseData['work_type'] ??
            supabaseData['workType'] ??
            merged['workType'];

        if (supabaseData['profile_image_url'] != null) {
          profileImageUrl = supabaseData['profile_image_url'];
        } else if (supabaseData['profile_image'] != null) {
          try {
            profileImageUrl = _supabaseService.getPublicUrl(
                'profile-images', supabaseData['profile_image']);
          } catch (e) {
            print('Error building public URL in HomeContent: $e');
          }
        }
      }

      if (profileImageUrl != null) merged['profileImageUrl'] = profileImageUrl;

      // Get team info if available
      try {
        final teamId = supabaseData?['team_id'];
        print('HomeContent: teamId => $teamId');
        if (teamId != null) {
          final teamData =
              await _supabaseService.getTeamByNoTeam(teamId.toString());
          print('HomeContent: teamData => $teamData');
          if (teamData != null) {
            merged['workTeam'] = teamData['work_team'] ?? merged['workTeam'];
            merged['workPlace'] = teamData['work_place'] ?? merged['workPlace'];
          }
        } else {
          merged['workTeam'] = supabaseData?['work_team'] ??
              supabaseData?['work_unit'] ??
              merged['workTeam'];
          merged['workPlace'] =
              supabaseData?['work_place'] ?? merged['workPlace'];
        }
      } catch (e) {
        print('Error loading team info in HomeContent: $e');
      }

      setState(() {
        _userData = merged;
      });

      print('Loaded user data: $_userData');
      print('Profile image URL: ${_userData?['profileImageUrl']}');
    } catch (e) {
      print('Error loading user data in HomeContent: $e');
    }
  }

  Future<void> _signOut() async {
    try {
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    } catch (e) {
      print('Error signing out: $e');
    }
  }

  void _toggleHeaderExpansion() {
    if (!mounted) return;
    setState(() {
      _isHeaderExpanded = !_isHeaderExpanded;
    });
  }

  // Add this function to handle URL launching
  Future<void> _launchURL(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
      } else {
        throw 'Could not launch $url';
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool isDarkMode = theme.brightness == Brightness.dark;

    // Colors that adapt to theme
    primaryColor = isDarkMode
        ? const Color.fromRGBO(180, 100, 100, 1) // Darker pink for dark mode
        : const Color.fromRGBO(224, 124, 124, 1);

    final cardColor = theme.cardColor;
    final textColor = theme.textTheme.bodyLarge?.color;
    final hintColor = theme.hintColor;

    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Pengguna dengan kemampuan stretch
            _buildExpandableUserHeader(primaryColor!),
            const SizedBox(height: 24),

            // Bahagian Quick Action
            _buildQuickActions(primaryColor!, cardColor, textColor),
            const SizedBox(height: 24),

            // Bahagian Berita
            _buildNewsSection(textColor),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // Widget untuk header pengguna yang dapat di-expand
  Widget _buildExpandableUserHeader(Color primaryColor) {
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyLarge?.color;

    return GestureDetector(
      onTap: _toggleHeaderExpansion,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: primaryColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: _isHeaderExpanded
            ? Stack(
                children: [
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // CircleAvatar dengan profile image dari Supabase
                      GestureDetector(
                        onTap: () {
                          // Open Manage Account screen to view/edit profile
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ManageAccountScreen(
                                user: _userData ?? <String, dynamic>{},
                              ),
                            ),
                          );
                        },
                        child: _buildProfileAvatar(radius: 40, iconSize: 40),
                      ),
                      const SizedBox(height: 20),
                      _buildDetailRow(
                        Icons.person,
                        _userData?['fullName'] ?? "Loading...",
                        maxLines: 2, // boleh jadi 2 baris untuk nama panjang
                      ),
                      const SizedBox(height: 12),
                      _buildDetailRow(
                        Icons.email,
                        _userData?['email'] ?? "Loading...",
                        maxLines: 2,
                      ),
                      const SizedBox(height: 12),
                      _buildDetailRow(
                        Icons.phone,
                        _userData?['phoneNumber'] ?? "Loading...",
                      ),
                      const SizedBox(height: 12),
                      // WorkTeam | WorkPlace: benarkan 2 baris dan gunakan center-left styling sedikit
                      _buildDetailRow(
                        Icons.business,
                        "${_userData?['workTeam'] ?? "Loading"} | ${_userData?['workPlace'] ?? "Loading"}",
                        maxLines: 2,
                        align: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      _buildDetailRow(
                        Icons.work,
                        _userData?['workType'] ?? "Loading...",
                        maxLines: 2,
                      ),
                      const SizedBox(height: 12),
                      const Icon(
                        Icons.keyboard_arrow_up,
                        color: Colors.white,
                        size: 30,
                      ),
                    ],
                  ),
                  Positioned(
                    top: 0,
                    right: 0,
                    child: IconButton(
                      onPressed: _signOut,
                      icon: const Icon(Icons.logout,
                          color: Colors.white, size: 28),
                    ),
                  ),
                ],
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      // CircleAvatar dengan profile image dari Supabase (small version)
                      GestureDetector(
                        onTap: () {
                          // Open Manage Account screen to view/edit profile
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ManageAccountScreen(
                                user: _userData ?? <String, dynamic>{},
                              ),
                            ),
                          );
                        },
                        child: _buildProfileAvatar(radius: 30, iconSize: 30),
                      ),
                      const SizedBox(width: 15),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Hello,",
                            style: TextStyle(fontSize: 18, color: Colors.white),
                          ),
                          Text(
                            _userData?['username'] ??
                                _userData?['fullName'] ??
                                "Loading...",
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: _signOut,
                        icon: const Icon(Icons.logout,
                            color: Colors.white, size: 28),
                      ),
                    ],
                  ),
                  const Icon(
                    Icons.keyboard_arrow_down,
                    color: Colors.white,
                    size: 30,
                  ),
                ],
              ),
      ),
    );
  }

  // Widget untuk CircleAvatar dengan profile image
  Widget _buildProfileAvatar(
      {required double radius, required double iconSize}) {
    final String? profileImageUrl = _userData?['profileImageUrl'] as String?;

    if (profileImageUrl != null && profileImageUrl.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: Colors.white,
        backgroundImage: NetworkImage(profileImageUrl),
        onBackgroundImageError: (exception, stackTrace) {
          // Fallback ke icon jika image gagal load
          print('Error loading profile image: $exception');
        },
      );
    } else {
      // Jika tidak ada profile image, tampilkan icon default
      return CircleAvatar(
        radius: radius,
        backgroundColor: Colors.white,
        child: Icon(Icons.person, size: iconSize, color: Colors.grey),
      );
    }
  }

  // Widget untuk baris detail (di expanded state)
  // Updated: support multiline and alignment
  Widget _buildDetailRow(IconData icon, String text,
      {int maxLines = 1, TextAlign align = TextAlign.center}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(width: 10),
          // Use Expanded so text takes remaining width and wraps nicely
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
              textAlign: align,
              maxLines: maxLines,
              overflow: TextOverflow.ellipsis,
              softWrap: true,
            ),
          ),
        ],
      ),
    );
  }

  // -----------------------------
  // Quick Actions - design with 3 columns (more compact)
  // -----------------------------
  Widget _buildQuickActions(
      Color primaryColor, Color cardColor, Color? textColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Quick Action",
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                )
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Kolom 1: kosong, Learning Hub, Facilities, kosong
                Expanded(
                  child: Column(
                    children: [
                      const SizedBox(height: 50),
                      _buildSmallActionCompact(
                          SvgPicture.asset("assets/svgs/Learning Hub.svg"),
                          "Learning\nHub",
                          primaryColor,
                          textColor),
                      const SizedBox(height: 20),
                      _buildSmallActionCompact(
                          SvgPicture.asset("assets/svgs/Facilities.svg"),
                          "Facilities\n",
                          primaryColor,
                          textColor),
                      const SizedBox(height: 50),
                    ],
                  ),
                ),

                // Kolom 2: My Document, My Journey, Task Manager
                Expanded(
                  child: Column(
                    children: [
                      _buildSmallActionCompact(
                          SvgPicture.asset("assets/svgs/My Document.svg"),
                          "My\nDocument",
                          primaryColor,
                          textColor),
                      const SizedBox(height: 20),
                      _buildCenterJourneyCompact(primaryColor),
                      const SizedBox(height: 20),
                      _buildSmallActionCompact(
                          SvgPicture.asset("assets/svgs/Task Manager.svg"),
                          "Task\nManager",
                          primaryColor,
                          textColor),
                    ],
                  ),
                ),

                // Kolom 3: kosong, Meet the Team, Buddy Chat, kosong
                Expanded(
                  child: Column(
                    children: [
                      const SizedBox(height: 50),
                      _buildSmallActionCompact(
                          SvgPicture.asset("assets/svgs/Meet the Team.svg"),
                          "Meet the\nTeam",
                          primaryColor,
                          textColor),
                      const SizedBox(height: 20),
                      _buildSmallActionCompact(
                          SvgPicture.asset("assets/svgs/Buddy Chat.svg"),
                          "Buddy\nChat",
                          primaryColor,
                          textColor),
                      const SizedBox(height: 50),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Compact small action item
  Widget _buildSmallActionCompact(
      Widget icon, String label, Color color, Color? textColor) {
    return GestureDetector(
      onTap: () {
        if (label == "Learning\nHub") {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const LearningHubScreen(),
            ),
          );
        }
        if (label == "Facilities\n") {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const TimelineScreen(),
            ),
          );
        }
        if (label == "My\nDocument") {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const DocumentManagerScreen(),
            ),
          );
        }
        if (label == "Task\nManager") {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const TaskManagerScreen(),
            ),
          );
        }
        if (label == "Meet the\nTeam") {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const MeetTheTeamScreen(),
            ),
          );
        }
        if (label == "Buddy\nChat") {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const HelpCenterScreen(),
            ),
          );
        }
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(width: 50, height: 50, child: icon),
          const SizedBox(height: 5),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: textColor),
          ),
        ],
      ),
    );
  }

  // Compact center big circular "My Journey"
  Widget _buildCenterJourneyCompact(Color color) {
    final theme = Theme.of(context);
    final bool isDarkMode = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const AppBarMyJourney()),
        );
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDarkMode
                  ? Colors.grey[800]
                  : const Color.fromRGBO(245, 245, 247, 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.12),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
                BoxShadow(
                  color: isDarkMode
                      ? Colors.black.withOpacity(0.18)
                      : Colors.white.withOpacity(0.18),
                  blurRadius: 16,
                  offset: const Offset(0, 0),
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Center(
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color,
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.28),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.flag, size: 60, color: Colors.white),
                      Text(
                        "My\nJourney",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 10,
                            color: Colors.white,
                            fontWeight: FontWeight.bold),
                      )
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // -----------------------------
  // News section with multiple news items and external links
  // -----------------------------
  Widget _buildNewsSection(Color? textColor) {
    // Sample news data - replace with your actual news data
    final List<Map<String, String>> newsItems = [
      {
        'title':
            'New App Onboard X: Cleaner, easier to use, and faster to navigate.',
        'image': 'assets/images/background_news.jpeg',
        'url': 'https://asean.bernama.com/news.php?id=2468953',
      },
      {
        'title': 'Latest Developments in Technology Sector',
        'image': 'assets/images/background_news.jpeg',
        'url': 'https://theedgemalaysia.com/node/770755',
      },
      {
        'title': 'Market Trends and Financial Updates',
        'image': 'assets/images/background_news.jpeg',
        'url': 'https://finance.yahoo.com/quote/5347.KL/news/',
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Text(
            "News",
            style: TextStyle(
                fontSize: 20, fontWeight: FontWeight.bold, color: textColor),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 180,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(left: 16),
            itemCount: newsItems.length,
            itemBuilder: (context, index) {
              final news = newsItems[index];
              return GestureDetector(
                onTap: () => _launchURL(news['url']!),
                child: Container(
                  width: 300,
                  margin: const EdgeInsets.only(right: 16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(15),
                    image: const DecorationImage(
                      image: AssetImage('assets/images/background_news.jpeg'),
                      fit: BoxFit.cover,
                      colorFilter: ColorFilter.mode(
                        Colors.black54,
                        BlendMode.darken,
                      ),
                    ),
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(15),
                      gradient: const LinearGradient(
                        colors: [Colors.black87, Colors.transparent],
                        begin: Alignment.bottomCenter,
                        end: Alignment.center,
                      ),
                    ),
                    child: Align(
                      alignment: Alignment.bottomLeft,
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Text(
                          news['title']!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
