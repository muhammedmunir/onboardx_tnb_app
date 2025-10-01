import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:onboardx_tnb_app/services/supabase_service.dart';

class ManageAccountScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  const ManageAccountScreen({super.key, required this.user});

  @override
  State<ManageAccountScreen> createState() => _ManageAccountScreenState();
}

class _ManageAccountScreenState extends State<ManageAccountScreen> {
  late TextEditingController nameCtrl;
  late TextEditingController phoneCtrl;
  late TextEditingController usernameCtrl;

  File? _pickedImage;
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;
  bool _editing = false;
  bool _loading = true;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final SupabaseService _supabaseService = SupabaseService();
  Map<String, dynamic> _userData = {};

  Color? get appBarIconColor => Theme.of(context).iconTheme.color;

  @override
  void initState() {
    super.initState();
    nameCtrl = TextEditingController();
    phoneCtrl = TextEditingController();
    usernameCtrl = TextEditingController();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    try {
      User? user = _auth.currentUser;
      if (user != null) {
        // Try to fetch from Supabase first using the new getUserProfile method
        final userProfile = await _supabaseService.getUserProfile(user.uid);
        
        if (userProfile != null) {
          setState(() {
            _userData = {
              'fullName': userProfile['full_name'] ?? '',
              'username': userProfile['username'] ?? '',
              'email': userProfile['email'] ?? '',
              'phoneNumber': userProfile['phone_number'] ?? '',
              'workUnit': userProfile['work_unit'] ?? '',
              'workplace': userProfile['work_place'] ?? '',
              'workType': userProfile['work_type'] ?? '',
              'profileImageUrl': userProfile['profile_image_url'],
              'createdAt': userProfile['created_at'] != null 
                  ? Timestamp.fromDate(DateTime.parse(userProfile['created_at']))
                  : null,
              'created_at': userProfile['created_at'],
            };
            
            nameCtrl.text = _userData['fullName'] ?? '';
            phoneCtrl.text = _userData['phoneNumber'] ?? '';
            usernameCtrl.text = _userData['username'] ?? '';
            _loading = false;
          });
        } else {
          // Fallback to Firestore if no Supabase data
          DocumentSnapshot userDoc = await _firestore
              .collection('users')
              .doc(user.uid)
              .get();

          if (userDoc.exists) {
            setState(() {
              _userData = userDoc.data() as Map<String, dynamic>;
              nameCtrl.text = _userData['fullName'] ?? '';
              phoneCtrl.text = _userData['phoneNumber'] ?? '';
              usernameCtrl.text = _userData['username'] ?? '';
              _loading = false;
            });
          } else {
            // If no data anywhere, use data from widget.user
            setState(() {
              _userData = widget.user;
              nameCtrl.text = _userData['fullName'] ?? '';
              phoneCtrl.text = _userData['phoneNumber'] ?? '';
              usernameCtrl.text = _userData['username'] ?? '';
              _loading = false;
            });
          }
        }
      }
    } catch (e) {
      print("Error fetching user data: $e");
      // Fallback to widget.user data if error occurs
      setState(() {
        _userData = widget.user;
        nameCtrl.text = _userData['fullName'] ?? '';
        phoneCtrl.text = _userData['phoneNumber'] ?? '';
        usernameCtrl.text = _userData['username'] ?? '';
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    phoneCtrl.dispose();
    usernameCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    if (!_editing) return;
    
    final picker = ImagePicker();
    final XFile? file = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 80,
    );
    
    if (file != null) {
      setState(() => _pickedImage = File(file.path));
    }
  }

  String _formatTimestamp(Timestamp timestamp) {
    final date = timestamp.toDate();
    final format = DateFormat('dd MMMM yyyy \'at\' HH:mm:ss');
    return format.format(date);
  }

  String _formatDateTime(String dateTimeString) {
    try {
      final date = DateTime.parse(dateTimeString);
      final format = DateFormat('dd MMMM yyyy \'at\' HH:mm:ss');
      return format.format(date);
    } catch (e) {
      return 'Unknown date';
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    try {
      User? user = _auth.currentUser;
      if (user == null) return;

      // Use the new updateUserProfile method from SupabaseService
      String? profileImagePath;
      if (_pickedImage != null) {
        profileImagePath = await _supabaseService.uploadProfileImage(user.uid, _pickedImage!);
      }

      await _supabaseService.updateUserProfile(
        uid: user.uid,
        fullName: nameCtrl.text.trim(),
        username: usernameCtrl.text.trim(),
        phoneNumber: phoneCtrl.text.trim(),
        profileImagePath: profileImagePath,
      );

      // Also update in Firestore for backward compatibility
      try {
        String? profileImageUrl;
        if (profileImagePath != null) {
          profileImageUrl = _supabaseService.getPublicUrl('profile-images', profileImagePath) as String?; // Tidak perlu await karena sekarang synchronous
        }

        await _firestore
            .collection('users')
            .doc(user.uid)
            .update({
              'fullName': nameCtrl.text.trim(),
              'phoneNumber': phoneCtrl.text.trim(),
              'username': usernameCtrl.text.trim(),
              if (profileImageUrl != null) 'profileImageUrl': profileImageUrl,
            });
      } catch (e) {
        print("Error updating Firestore: $e");
        // Continue even if Firestore update fails
      }

      // Refresh user data after update
      await _fetchUserData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
        setState(() {
          _editing = false;
          _pickedImage = null;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating profile: $e'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).textTheme.bodyLarge?.color,
        ),
      ),
    );
  }

  Widget _buildReadOnlyField(String title, String value) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).textTheme.bodySmall?.color,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  value.isNotEmpty ? value : 'Not set',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool isDarkMode = theme.brightness == Brightness.dark;
    final primaryColor = isDarkMode 
        ? const Color.fromRGBO(180, 100, 100, 1)
        : const Color.fromRGBO(224, 124, 124, 1);
    final cardColor = theme.cardColor;

    final Timestamp? createdAt = _userData['createdAt'];
    final String? createdAtString = _userData['created_at'];

    if (_loading) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                color: primaryColor,
              ),
              const SizedBox(height: 16),
              Text(
                'Loading profile...',
                style: TextStyle(
                  color: theme.textTheme.bodyLarge?.color,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Manage Your Account'),
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
                color: primaryColor,
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
          if (!_editing)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () {
                setState(() => _editing = true);
              },
              tooltip: 'Edit Profile',
            ),
          if (_editing)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                setState(() {
                  _editing = false;
                  // Reset changes
                  nameCtrl.text = _userData['fullName'] ?? '';
                  phoneCtrl.text = _userData['phoneNumber'] ?? '';
                  usernameCtrl.text = _userData['username'] ?? '';
                  _pickedImage = null;
                });
              },
              tooltip: 'Cancel Editing',
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 16),
            
            // Profile Image Section
            Column(
              children: [
                GestureDetector(
                  onTap: _pickImage,
                  child: Stack(
                    children: [
                      // Profile Image with different states
                      if (_pickedImage != null)
                        CircleAvatar(
                          radius: 48,
                          backgroundImage: FileImage(_pickedImage!),
                        )
                      else if (_userData['profileImageUrl'] != null && _userData['profileImageUrl'].isNotEmpty)
                        CircleAvatar(
                          radius: 48,
                          backgroundImage: NetworkImage(_userData['profileImageUrl']),
                          onBackgroundImageError: (exception, stackTrace) {
                            print("Error loading profile image: $exception");
                          },
                        )
                      else
                        const CircleAvatar(
                          radius: 48,
                          backgroundColor: Colors.white,
                          child: Icon(Icons.person, size: 40, color: Colors.grey),
                        ),
                      
                      // Camera icon for editing
                      if (_editing)
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: primaryColor,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.camera_alt,
                              size: 20,
                              color: Colors.white,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _editing ? 'Tap avatar to change photo' : '',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 24),

            Form(
              key: _formKey,
              child: Column(
                children: [
                  _buildSectionHeader('Account Information'),
                  
                  // Username Field
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _editing
                        ? TextFormField(
                            controller: usernameCtrl,
                            decoration: InputDecoration(
                              labelText: 'Username',
                              hintText: 'Enter your username',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              fillColor: cardColor,
                              prefixIcon: Icon(Icons.person, color: primaryColor),
                            ),
                            validator: (v) =>
                                (v ?? '').trim().isEmpty ? 'Username is required' : null,
                          )
                        : _buildReadOnlyField('Username', _userData['username'] ?? ''),
                  ),
                  const SizedBox(height: 16),
                  
                  // Full Name Field
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _editing
                        ? TextFormField(
                            controller: nameCtrl,
                            decoration: InputDecoration(
                              labelText: 'Full Name',
                              hintText: 'Enter your full name',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              fillColor: cardColor,
                              prefixIcon: Icon(Icons.badge, color: primaryColor),
                            ),
                            validator: (v) =>
                                (v ?? '').trim().isEmpty ? 'Full name is required' : null,
                          )
                        : _buildReadOnlyField('Full Name', _userData['fullName'] ?? ''),
                  ),
                  const SizedBox(height: 16),
                  
                  // Email Field (always read-only)
                  _buildReadOnlyField('Email', _userData['email'] ?? ''),
                  const SizedBox(height: 16),
                  
                  // Phone Number Field
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _editing
                        ? TextFormField(
                            controller: phoneCtrl,
                            decoration: InputDecoration(
                              labelText: 'Phone Number',
                              hintText: 'Enter your phone number',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              fillColor: cardColor,
                              prefixIcon: Icon(Icons.phone, color: primaryColor),
                            ),
                            keyboardType: TextInputType.phone,
                            validator: (v) => (v != null && v.length >= 9)
                                ? null
                                : 'Please enter a valid phone number',
                          )
                        : _buildReadOnlyField('Phone Number', _userData['phoneNumber'] ?? ''),
                  ),
                  const SizedBox(height: 24),

                  _buildSectionHeader('Work Information'),
                  _buildReadOnlyField('Work Type', _userData['workType'] ?? ''),
                  _buildReadOnlyField('Work Unit', _userData['workUnit'] ?? ''),
                  _buildReadOnlyField('Workplace', _userData['workplace'] ?? ''),
                  const SizedBox(height: 24),

                  _buildSectionHeader('Account Metadata'),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today_outlined, color: primaryColor),
                        const SizedBox(width: 16),
                        const Text('Created at'),
                        const Spacer(),
                        Text(
                          createdAt != null 
                            ? _formatTimestamp(createdAt)
                            : (createdAtString != null 
                                ? _formatDateTime(createdAtString)
                                : 'Unknown'),
                          style: TextStyle(
                            color: Theme.of(context).textTheme.bodySmall?.color,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Save Button (only when editing)
                  if (_editing) ...[
                    const SizedBox(height: 32),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _saving ? null : _saveProfile,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 2,
                          ),
                          child: _saving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'Save Changes',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}