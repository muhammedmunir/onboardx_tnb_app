import 'package:flutter/material.dart';
import 'package:onboardx_tnb_app/screens/auth/login_screen.dart';
import 'package:onboardx_tnb_app/services/auth_service.dart';
import 'package:onboardx_tnb_app/services/supabase_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _firebaseAuth = AuthService();
  final _supabaseService = SupabaseService();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _teamController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  String? _selectedWorkType;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isValidTeam = false;
  Map<String, dynamic>? _selectedTeam;

  final List<String> _workTypes = [
    'Pre-staff',
    'Bodyshop',
    'Protege',
    'Intern'
  ];

  // Add form key
  final _formKey = GlobalKey<FormState>();

  void _clearAllFields() {
    _nameController.clear();
    _usernameController.clear();
    _emailController.clear();
    _phoneController.clear();
    _teamController.clear();
    _passwordController.clear();
    _confirmPasswordController.clear();
    setState(() {
      _selectedWorkType = null;
      _isValidTeam = false;
      _selectedTeam = null;
    });
  }

  // Di RegisterScreen, perbaiki method _validateTeam:
  Future<void> _validateTeam() async {
    if (_teamController.text.isEmpty) {
      setState(() {
        _isValidTeam = false;
        _selectedTeam = null;
      });
      return;
    }

    try {
      // Gunakan getTeamByNoTeam bukan getTeamByTeamId
      final team =
          await _supabaseService.getTeamByNoTeam(_teamController.text.trim());
      if (team != null) {
        setState(() {
          _isValidTeam = true;
          _selectedTeam = team;
        });
      } else {
        setState(() {
          _isValidTeam = false;
          _selectedTeam = null;
        });
      }
    } catch (e) {
      setState(() {
        _isValidTeam = false;
        _selectedTeam = null;
      });
    }
  }

  void _register() async {
    // Validate form
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Validate team
    if (!_isValidTeam || _selectedTeam == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid team number'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Call AuthService to register with email and password
      User? user = await _firebaseAuth.registerWithEmail(
        _emailController.text,
        _passwordController.text,
      );

      if (user != null) {
        // Save user data to Supabase
        final userData = {
          'uid': user.uid,
          'full_name': _nameController.text,
          'username': _usernameController.text,
          'email': _emailController.text,
          'phone_number': _phoneController.text,
          'work_type': _selectedWorkType,
          'team_id': _selectedTeam!['id'],
          'profile_image': null,
          'created_at': DateTime.now().toUtc().toIso8601String(),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        };

        await _supabaseService.createUser(userData);

        // Send email verification
        await user.sendEmailVerification();

        // Clear all fields after successful registration
        _clearAllFields();

        // Show verification dialog
        _showVerificationDialog(context);
      } else {
        // Registration failed
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Registration failed. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      // Handle errors
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showVerificationDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Email Verification Required'),
          content: const Text(
              'A verification email has been sent to your email address. '
              'Please verify your email before logging in.'),
          actions: <Widget>[
            TextButton(
              child: const Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const LoginScreen(),
                  ),
                );
              },
            ),
            TextButton(
              child: const Text('Resend Verification'),
              onPressed: () async {
                try {
                  User? user = FirebaseAuth.instance.currentUser;
                  if (user != null) {
                    await user.sendEmailVerification();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Verification email resent!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error resending email: ${e.toString()}'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final theme = Theme.of(context);
    final bool isDarkMode = theme.brightness == Brightness.dark;

    // Colors that adapt to theme
    final primaryColor = isDarkMode
        ? const Color.fromRGBO(180, 100, 100, 1)
        : const Color.fromRGBO(224, 124, 124, 1);

    final cardColor = theme.cardColor;
    final textColor = theme.textTheme.bodyLarge?.color;
    final hintColor = theme.hintColor;
    const successColor = Colors.green;
    const errorColor = Colors.red;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Stack(
          children: [
            // Background hexagon - adjust for dark mode
            Container(
              decoration: BoxDecoration(
                image: DecorationImage(
                  image:
                      const AssetImage("assets/images/background_Splash.jpg"),
                  fit: BoxFit.cover,
                  colorFilter: isDarkMode
                      ? ColorFilter.mode(
                          Colors.black.withOpacity(0.7), BlendMode.darken)
                      : null,
                ),
              ),
            ),

            // Fixed Semi circle atas
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 200,
                decoration: BoxDecoration(
                  color: primaryColor,
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(300),
                  ),
                ),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 40.0),
                    child: Image.asset(
                      "assets/images/logo_OnboardingX.png",
                      width: 200,
                    ),
                  ),
                ),
              ),
            ),

            // Fixed Semi circle bawah
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 200,
                decoration: BoxDecoration(
                  color: primaryColor,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(300),
                  ),
                ),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 40.0),
                    child: Image.asset(
                      "assets/images/logo_tnb.png",
                      width: 170,
                    ),
                  ),
                ),
              ),
            ),

            // Content Area
            SafeArea(
              child: Align(
                alignment: Alignment.center,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    children: [
                      // Spacer to push content below top semicircle
                      SizedBox(height: size.height * 0.22),

                      // Register Form Card
                      Container(
                        padding: const EdgeInsets.all(24.0),
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                "Sign Up",
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: textColor,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 20),

                              // Name
                              TextFormField(
                                controller: _nameController,
                                style: TextStyle(color: textColor),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter your full name';
                                  }
                                  return null;
                                },
                                decoration: InputDecoration(
                                  labelText: "Full Name",
                                  labelStyle: TextStyle(color: hintColor),
                                  border: const UnderlineInputBorder(),
                                  prefixIcon:
                                      Icon(Icons.person, color: hintColor),
                                ),
                              ),
                              const SizedBox(height: 15),

                              // Username
                              TextFormField(
                                controller: _usernameController,
                                style: TextStyle(color: textColor),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter your username';
                                  }
                                  if (value
                                          .trim()
                                          .split(RegExp(r'\s+'))
                                          .length >
                                      12) {
                                    return 'Username must be max 12 words';
                                  }
                                  return null;
                                },
                                decoration: InputDecoration(
                                  labelText: "Username",
                                  labelStyle: TextStyle(color: hintColor),
                                  border: const UnderlineInputBorder(),
                                  prefixIcon: Icon(Icons.person_outline,
                                      color: hintColor),
                                ),
                              ),
                              const SizedBox(height: 15),

                              // Email
                              TextFormField(
                                controller: _emailController,
                                style: TextStyle(color: textColor),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter your email';
                                  }
                                  if (!RegExp(
                                          r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                                      .hasMatch(value)) {
                                    return 'Please enter a valid email';
                                  }
                                  return null;
                                },
                                decoration: InputDecoration(
                                  labelText: "Email",
                                  labelStyle: TextStyle(color: hintColor),
                                  border: const UnderlineInputBorder(),
                                  prefixIcon:
                                      Icon(Icons.email, color: hintColor),
                                ),
                                keyboardType: TextInputType.emailAddress,
                              ),
                              const SizedBox(height: 15),

                              // Phone Number
                              TextFormField(
                                controller: _phoneController,
                                style: TextStyle(color: textColor),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter your phone number';
                                  }
                                  if (!RegExp(r'^[0-9]{10,}$')
                                      .hasMatch(value)) {
                                    return 'Please enter a valid phone number';
                                  }
                                  return null;
                                },
                                decoration: InputDecoration(
                                  labelText: "Phone Number",
                                  labelStyle: TextStyle(color: hintColor),
                                  border: const UnderlineInputBorder(),
                                  prefixIcon:
                                      Icon(Icons.phone, color: hintColor),
                                ),
                                keyboardType: TextInputType.phone,
                              ),
                              const SizedBox(height: 15),

                              // Team Number dengan validasi real-time
                              TextFormField(
                                controller: _teamController,
                                style: TextStyle(color: textColor),
                                onChanged: (value) => _validateTeam(),
                                decoration: InputDecoration(
                                  labelText: "Team Number",
                                  labelStyle: TextStyle(color: hintColor),
                                  border: const UnderlineInputBorder(),
                                  prefixIcon:
                                      Icon(Icons.group, color: hintColor),
                                  suffixIcon: _teamController.text.isNotEmpty
                                      ? Icon(
                                          _isValidTeam
                                              ? Icons.check_circle
                                              : Icons.error,
                                          color: _isValidTeam
                                              ? successColor
                                              : errorColor,
                                        )
                                      : null,
                                  hintText: "Enter your assigned team number",
                                ),
                              ),
                              if (_teamController.text.isNotEmpty &&
                                  !_isValidTeam)
                                const Padding(
                                  padding: EdgeInsets.only(top: 8.0),
                                  child: Text(
                                    'Invalid team number. Please check with your administrator.',
                                    style: TextStyle(
                                      color: errorColor,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              if (_isValidTeam && _selectedTeam != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Team: ${_selectedTeam!['work_team']}',
                                        style: const TextStyle(
                                          color: successColor,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        'Workplace: ${_selectedTeam!['work_place']}',
                                        style: const TextStyle(
                                          color: successColor,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              const SizedBox(height: 15),

                              // Work Type Dropdown
                              DropdownButtonFormField<String>(
                                value: _selectedWorkType,
                                dropdownColor: cardColor,
                                style: TextStyle(color: textColor),
                                decoration: InputDecoration(
                                  labelText: "Work Type",
                                  labelStyle: TextStyle(color: hintColor),
                                  border: const UnderlineInputBorder(),
                                  prefixIcon:
                                      Icon(Icons.category, color: hintColor),
                                ),
                                isExpanded: true,
                                hint: Text("Select work type",
                                    style: TextStyle(color: hintColor)),
                                items: _workTypes.map((String value) {
                                  return DropdownMenuItem<String>(
                                    value: value,
                                    child: Text(value,
                                        style: TextStyle(color: textColor)),
                                  );
                                }).toList(),
                                onChanged: (String? newValue) {
                                  setState(() {
                                    _selectedWorkType = newValue;
                                  });
                                },
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please select a work type';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 15),

                              // Password
                              TextFormField(
                                controller: _passwordController,
                                obscureText: _obscurePassword,
                                style: TextStyle(color: textColor),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter a password';
                                  }
                                  if (value.length < 12) {
                                    return 'Password must be at least 12 characters';
                                  }
                                  if (!RegExp(r'[0-9]').hasMatch(value)) {
                                    return 'Password must contain at least one number';
                                  }
                                  if (!RegExp(r'[!@#\$%^&*(),.?":{}|<>]')
                                      .hasMatch(value)) {
                                    return 'Password must contain at least one symbol';
                                  }
                                  if (!RegExp(r'[A-Z]').hasMatch(value)) {
                                    return 'Password must contain at least one uppercase letter';
                                  }
                                  if (!RegExp(r'[a-z]').hasMatch(value)) {
                                    return 'Password must contain at least one lowercase letter';
                                  }
                                  return null;
                                },
                                decoration: InputDecoration(
                                  labelText: "Password",
                                  labelStyle: TextStyle(color: hintColor),
                                  border: const UnderlineInputBorder(),
                                  prefixIcon:
                                      Icon(Icons.lock, color: hintColor),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility
                                          : Icons.visibility_off,
                                      color: hintColor,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _obscurePassword = !_obscurePassword;
                                      });
                                    },
                                  ),
                                ),
                              ),
                              const SizedBox(height: 15),

                              // Confirm Password
                              TextFormField(
                                controller: _confirmPasswordController,
                                obscureText: _obscureConfirmPassword,
                                style: TextStyle(color: textColor),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please confirm your password';
                                  }
                                  if (value != _passwordController.text) {
                                    return 'Passwords do not match';
                                  }
                                  return null;
                                },
                                decoration: InputDecoration(
                                  labelText: "Confirm Password",
                                  labelStyle: TextStyle(color: hintColor),
                                  border: const UnderlineInputBorder(),
                                  prefixIcon: Icon(Icons.lock_outline,
                                      color: hintColor),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscureConfirmPassword
                                          ? Icons.visibility
                                          : Icons.visibility_off,
                                      color: hintColor,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _obscureConfirmPassword =
                                            !_obscureConfirmPassword;
                                      });
                                    },
                                  ),
                                ),
                              ),
                              const SizedBox(height: 30),

                              // Button Register
                              _isLoading
                                  ? const Center(
                                      child: CircularProgressIndicator())
                                  : ElevatedButton(
                                      onPressed:
                                          _isValidTeam ? _register : null,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: _isValidTeam
                                            ? primaryColor
                                            : Colors.grey,
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 16),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(30),
                                        ),
                                      ),
                                      child: const Text(
                                        "Register",
                                        style: TextStyle(
                                            fontSize: 18, color: Colors.white),
                                      ),
                                    ),
                              const SizedBox(height: 20),

                              // Login link
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    "Already have an account? ",
                                    style: TextStyle(
                                      color: hintColor,
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () {
                                      Navigator.pushReplacement(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              const LoginScreen(),
                                        ),
                                      );
                                    },
                                    child: Text(
                                      "Login Now",
                                      style: TextStyle(
                                        color: primaryColor,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Bottom spacer to ensure content doesn't overlap with bottom semicircle
                      SizedBox(height: size.height * 0.25),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
