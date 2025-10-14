import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:onboardx_tnb_app/firebase_options.dart';
import 'package:onboardx_tnb_app/l10n/app_localizations.dart';
import 'package:onboardx_tnb_app/screens/auth/login_screen.dart';
import 'package:onboardx_tnb_app/screens/home/home_screen.dart';
import 'package:provider/provider.dart';
import 'package:onboardx_tnb_app/providers/local_auth_provider.dart';
import 'package:onboardx_tnb_app/providers/locale_provider.dart'; // Add locale provider
import 'package:onboardx_tnb_app/services/theme_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await Supabase.initialize(
    url: 'https://onboardx.jomcloud.com',
    anonKey: 'eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJpc3MiOiJzdXBhYmFzZSIsImlhdCI6MTc1OTA3MzQ2MCwiZXhwIjo0OTE0NzQ3MDYwLCJyb2xlIjoiYW5vbiJ9.uwjzLVaB3pmtadpSjahKtCRdWGbvntFpFOBCSQLMkck',
  );

  // Ensure default theme is light mode
  themeNotifier.value = ThemeMode.light;

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LocalAuthenticationProvider()),
        ChangeNotifierProvider(create: (context) => LocaleProvider()..loadLocale()),
      ],
      child: ValueListenableBuilder<ThemeMode>(
        valueListenable: themeNotifier,
        builder: (context, ThemeMode currentMode, _) {
          return Consumer<LocaleProvider>(
            builder: (context, localeProvider, child) {
              return MaterialApp(
                title: 'OnboardX TNB',
                debugShowCheckedModeBanner: false,
                theme: ThemeData(
                  brightness: Brightness.light,
                  primarySwatch: Colors.red,
                  visualDensity: VisualDensity.adaptivePlatformDensity,
                  textTheme: GoogleFonts.poppinsTextTheme(ThemeData.light().textTheme),
                  scaffoldBackgroundColor: const Color(0xFFF5F5F7),
                  appBarTheme: AppBarTheme(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    elevation: 0,
                    titleTextStyle: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                    iconTheme: const IconThemeData(color: Colors.black),
                  ),
                  iconTheme: const IconThemeData(color: Colors.black87),
                  listTileTheme: const ListTileThemeData(
                    iconColor: Colors.black87,
                    textColor: Colors.black87,
                  ),
                ),
                darkTheme: ThemeData(
                  brightness: Brightness.dark,
                  primarySwatch: Colors.red,
                  visualDensity: VisualDensity.adaptivePlatformDensity,
                  textTheme: GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme).apply(
                    bodyColor: Colors.white,
                    displayColor: Colors.white,
                  ),
                  scaffoldBackgroundColor: const Color(0xFF121212),
                  appBarTheme: AppBarTheme(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    titleTextStyle: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                    iconTheme: const IconThemeData(color: Colors.white),
                  ),
                  iconTheme: const IconThemeData(color: Colors.white),
                  listTileTheme: const ListTileThemeData(
                    iconColor: Colors.white,
                    textColor: Colors.white,
                  ),
                ),
                themeMode: currentMode,
                locale: localeProvider.locale,
                localizationsDelegates: const [
                  AppLocalizations.delegate,
                  GlobalMaterialLocalizations.delegate,
                  GlobalWidgetsLocalizations.delegate,
                  GlobalCupertinoLocalizations.delegate,
                ],
                supportedLocales: const [
                  Locale('en'), // English
                  Locale('ms'), // Malay
                ],
                home: const AuthWrapper(),
              );
            },
          );
        },
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.active) {
          if (snapshot.hasError) {
            return Scaffold(
              body: Center(
                child: Text(AppLocalizations.of(context)!.somethingWentWrong),
              ),
            );
          }

          User? user = snapshot.data;
          if (user != null) {
            if (user.emailVerified) {
              return const HomeScreen();
            } else {
              // User is signed in but email is not verified
              return const LoginScreen();
            }
          }
          return const LoginScreen();
        }
        return const Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        );
      },
    );
  }
}