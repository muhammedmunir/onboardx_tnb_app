import 'package:flutter/material.dart';
import 'package:onboardx_tnb_app/screens/home/home_screen.dart';
import 'package:onboardx_tnb_app/screens/auth/forget_password_screen.dart';
import 'package:onboardx_tnb_app/screens/auth/register_screen.dart';
import 'package:onboardx_tnb_app/services/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:onboardx_tnb_app/providers/local_auth_provider.dart';
import 'package:provider/provider.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  static const String _kLoginStatusKey = 'loginStatus';
  bool _showBiometricButton = false;

  final AuthService _authService = AuthService();
  final _formKey = GlobalKey<FormState>();

  // secure storage untuk simpan credentials
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  static const String _kBiometricEnabledKey = 'biometric_enabled';
  static const String _kSavedEmailKey = 'saved_email';
  static const String _kSavedPasswordKey = 'saved_password';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _checkEmailVerificationOnStart();
      await _evaluateBiometricAvailability();
      await _tryAutoBiometricLogin();
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _evaluateBiometricAvailability() async {
    try {
      final localAuthProv =
          Provider.of<LocalAuthenticationProvider>(context, listen: false);
      final prefs = await SharedPreferences.getInstance();
      final canCheck = await localAuthProv.checkBiometricAvailability();
      final bioEnabled = prefs.getBool(_kBiometricEnabledKey) ?? false;

      // Also check available biometrics and saved credentials
      final available = await localAuthProv.getAvailableBiometrics();
      final savedEmail = await _secureStorage.read(key: _kSavedEmailKey) ?? '';
      final savedPassword =
          await _secureStorage.read(key: _kSavedPasswordKey) ?? '';

      debugPrint(
          'evaluateBiometricAvailability -> canCheck: $canCheck, bioEnabled: $bioEnabled, available: $available, savedEmail: ${savedEmail.isNotEmpty}');

      setState(() {
        _showBiometricButton = canCheck &&
            bioEnabled &&
            available.isNotEmpty &&
            savedEmail.isNotEmpty &&
            savedPassword.isNotEmpty;
      });
    } catch (e) {
      // if something fails, just hide biometric button
      debugPrint('evaluateBiometricAvailability error -> $e');
      setState(() {
        _showBiometricButton = false;
      });
    }
  }

  Future<void> _tryAutoBiometricLogin() async {
    final localAuthProv =
        Provider.of<LocalAuthenticationProvider>(context, listen: false);
    final prefs = await SharedPreferences.getInstance();

    final bool bioEnabled = prefs.getBool(_kBiometricEnabledKey) ?? false;
    if (!bioEnabled) {
      debugPrint('_tryAutoBiometricLogin -> biometric not enabled in prefs');
      return;
    }

    final canCheck = await localAuthProv.checkBiometricAvailability();
    if (!canCheck) {
      debugPrint('_tryAutoBiometricLogin -> device cannot check biometrics');
      return;
    }

    // Baca credentials dari secure storage
    String savedEmail = '';
    String savedPassword = '';
    try {
      savedEmail = await _secureStorage.read(key: _kSavedEmailKey) ?? '';
      savedPassword = await _secureStorage.read(key: _kSavedPasswordKey) ?? '';
    } catch (e) {
      // ignore read error, fallback
      debugPrint('_tryAutoBiometricLogin read secure storage error -> $e');
    }

    if (savedEmail.isNotEmpty && savedPassword.isNotEmpty) {
      final result = await localAuthProv.authenticateWithBiometricsDetailed(
        localizedReason: 'Authenticate to sign in with saved credentials',
      );
      debugPrint('Auto biometric login authenticate result: $result');
      if (result['success'] == true) {
        setState(() {
          _isLoading = true;
        });
        try {
          User? user =
              await _authService.signInWithEmail(savedEmail, savedPassword);
          if (user != null) {
            if (user.emailVerified) {
              // set loginStatus only after successful login
              await prefs.setBool(_kLoginStatusKey, true);

              if (mounted) {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const HomeScreen()),
                );
              }
            } else {
              // jika belum verify, paparkan dialog sama seperti normal flow
              if (mounted) _showVerificationDialog(context, user);
            }
          } else {
            // gagal login — beri notifikasi
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Auto biometric login failed.'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Auto login error: ${e.toString()}')),
            );
          }
        } finally {
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
          }
        }
      } else {
        // show message why failed
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content:
                    Text('Auto biometric auth failed: ${result['message']}'),
                backgroundColor: Colors.red),
          );
        }
      }
    } else {
      debugPrint('_tryAutoBiometricLogin -> no saved credentials found');
    }
  }

  void _login() async {
    // Validate form
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Call AuthService to login with email and password
      User? user = await _authService.signInWithEmail(
        _emailController.text.trim(),
        _passwordController.text,
      );

      if (user != null) {
        // Check if email is verified - INI YANG PENTING!
        if (user.emailVerified) {
          // selepas berjaya login, tanya user nak enable biometric?
          await _offerEnableBiometricIfAvailable(
              _emailController.text.trim(), _passwordController.text);

          // set loginStatus only after successful login
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool(_kLoginStatusKey, true);

          // Login successful and email verified - navigate to home screen
          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const HomeScreen()),
            );
          }
        } else {
          // Email not verified - TAMPILKAN DIALOG DAN JANGAN IZIN MASUK
          _showVerificationDialog(context, user);

          // SIGN OUT USER karena email belum terverifikasi
          await _authService.signOut();

          setState(() {
            _isLoading = false;
          });
          return; // Berhenti di sini, jangan lanjutkan
        }
      } else {
        // Login failed
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Login failed. Please check your credentials.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage = 'Login failed. Please try again.';

      if (e.code == 'user-not-found') {
        errorMessage = 'No user found with this email.';
      } else if (e.code == 'wrong-password') {
        errorMessage = 'Incorrect password.';
      } else if (e.code == 'invalid-email') {
        errorMessage = 'Invalid email address.';
      } else if (e.code == 'user-disabled') {
        errorMessage = 'This account has been disabled.';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
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
      // re-evaluate biometric button (in case user just enabled biometric)
      await _evaluateBiometricAvailability();
    }
  }

  Future<void> _checkEmailVerificationOnStart() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && !user.emailVerified) {
      await _authService.signOut();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kLoginStatusKey, false);
    }
  }

  Future<void> _offerEnableBiometricIfAvailable(
      String email, String password) async {
    final localAuthProv =
        Provider.of<LocalAuthenticationProvider>(context, listen: false);
    final prefs = await SharedPreferences.getInstance();

    final bool canCheck = await localAuthProv.checkBiometricAvailability();
    final bool alreadyEnabled = prefs.getBool(_kBiometricEnabledKey) ?? false;

    if (!canCheck || alreadyEnabled) {
      debugPrint(
          '_offerEnableBiometricIfAvailable -> cant check or already enabled');
      return;
    }

    // Tawarkan dialog untuk aktifkan biometric — ini TIDAK ubah UI utama (pop-up sahaja)
    if (!mounted) return;
    final enable = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext ctx) {
        return AlertDialog(
          title: const Text('Enable Biometric Login?'),
          content: const Text(
              'Do you want to enable biometric login for faster sign-in next time?'),
          actions: <Widget>[
            TextButton(
              child: const Text('No'),
              onPressed: () => Navigator.of(ctx).pop(false),
            ),
            TextButton(
              child: const Text('Yes'),
              onPressed: () => Navigator.of(ctx).pop(true),
            ),
          ],
        );
      },
    );

    if (enable == true) {
      // cuba authenticate dulu untuk confirm identity sebelum simpan
      final result = await localAuthProv.authenticateWithBiometricsDetailed(
        localizedReason: 'Confirm to enable biometric login',
      );
      debugPrint('Biometric enable attempt result: $result');

      if (result['success'] == true) {
        // simpan email/password ke secure storage
        await _secureStorage.write(key: _kSavedEmailKey, value: email);
        await _secureStorage.write(key: _kSavedPasswordKey, value: password);
        await prefs.setBool(_kBiometricEnabledKey, true);

        // update show button immediately
        setState(() {
          _showBiometricButton = true;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Biometric login enabled.'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Could not enable biometric. ${result['message']}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _fingerPrintLogin() async {
    final localAuthProv =
        Provider.of<LocalAuthenticationProvider>(context, listen: false);
    final prefs = await SharedPreferences.getInstance();

    setState(() {
      _isLoading = true;
    });

    try {
      final bool bioEnabled = prefs.getBool(_kBiometricEnabledKey) ?? false;
      final bool canCheck = await localAuthProv.checkBiometricAvailability();

      if (!bioEnabled || !canCheck) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Biometric not available or not enabled.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      final result = await localAuthProv.authenticateWithBiometricsDetailed(
        localizedReason: 'Authenticate to sign in',
      );
      debugPrint('Fingerprint button authenticate result: $result');
      if (result['success'] != true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    'Biometric authentication failed: ${result['message']}'),
                backgroundColor: Colors.red),
          );
        }
        return;
      }

      // baca credentials dari secure storage
      String savedEmail = '';
      String savedPassword = '';
      try {
        savedEmail = await _secureStorage.read(key: _kSavedEmailKey) ?? '';
        savedPassword =
            await _secureStorage.read(key: _kSavedPasswordKey) ?? '';
      } catch (e) {
        debugPrint('_fingerPrintLogin read secure storage error -> $e');
      }

      if (savedEmail.isEmpty || savedPassword.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No saved credentials found for biometric login.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // cuba sign-in dengan credentials tersimpan
      User? user =
          await _authService.signInWithEmail(savedEmail, savedPassword);
      if (user != null) {
        if (user.emailVerified) {
          // set loginStatus only after successful login
          await prefs.setBool(_kLoginStatusKey, true);

          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const HomeScreen()),
            );
          }
        } else {
          if (mounted) _showVerificationDialog(context, user);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Biometric login failed.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showVerificationDialog(BuildContext context, User user) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Email Not Verified'),
          content:
              const Text('Please verify your email address before logging in. '
                  'Check your inbox for a verification email.'),
          actions: <Widget>[
            TextButton(
              child: const Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Resend Verification'),
              onPressed: () async {
                try {
                  await user.sendEmailVerification();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Verification email sent!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                  Navigator.of(context).pop();
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: ${e.toString()}'),
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
        ? const Color.fromRGBO(180, 100, 100, 1) // Darker pink for dark mode
        : const Color.fromRGBO(224, 124, 124, 1);

    final cardColor = theme.cardColor;
    final textColor = theme.textTheme.bodyLarge?.color;
    final hintColor = theme.hintColor;
    final scaffoldBackground = theme.scaffoldBackgroundColor;

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

                      // Login Card
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
                                "Sign In",
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: textColor,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 20),

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
                              const SizedBox(height: 20),

                              // Password
                              TextFormField(
                                controller: _passwordController,
                                obscureText: _obscurePassword,
                                style: TextStyle(color: textColor),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter your password';
                                  }
                                  if (value.length < 6) {
                                    return 'Password must be at least 6 characters';
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
                              const SizedBox(height: 10),

                              // Forget Password
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            const ForgotPasswordScreen(),
                                      ),
                                    );
                                  },
                                  child: Text(
                                    "Forget Password?",
                                    style: TextStyle(
                                      color: primaryColor,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),

                              // Button Login + Biometric di sebelah
                              _isLoading
                                  ? const Center(
                                      child: CircularProgressIndicator())
                                  : Row(
                                      children: [
                                        Expanded(
                                          flex: 5,
                                          child: ElevatedButton(
                                            onPressed: _login,
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: primaryColor,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      vertical: 16),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(30),
                                              ),
                                            ),
                                            child: const Text(
                                              "Login",
                                              style: TextStyle(
                                                  fontSize: 18,
                                                  color: Colors.white),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        // Biometric button - hanya ditunjuk bila sesuai
                                        _showBiometricButton
                                            ? Container(
                                                width: 56,
                                                height: 48,
                                                child: ElevatedButton(
                                                  onPressed: _fingerPrintLogin,
                                                  style:
                                                      ElevatedButton.styleFrom(
                                                    backgroundColor:
                                                        primaryColor,
                                                    padding: EdgeInsets.zero,
                                                    shape:
                                                        RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              12),
                                                    ),
                                                    elevation: 4,
                                                  ),
                                                  child: Icon(
                                                    Icons.fingerprint,
                                                    size: 26,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              )
                                            : const SizedBox(width: 0),
                                      ],
                                    ),

                              const SizedBox(height: 20),
                              // Register link
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    "Don't have an account? ",
                                    style: TextStyle(
                                      color: hintColor,
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              const RegisterScreen(),
                                        ),
                                      );
                                    },
                                    child: Text(
                                      "Register Now",
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
