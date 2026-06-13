import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_database/firebase_database.dart';
import 'core/app_colors.dart';
import 'services/notification_service.dart';
import 'screens/dashboard_screen.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await Firebase.initializeApp();
    
    // Enable data persistence for offline support
    FirebaseDatabase.instance.setPersistenceEnabled(true);
    FirebaseDatabase.instance.ref("permissions").keepSynced(true);
    FirebaseDatabase.instance.ref("settings").keepSynced(true);
    FirebaseDatabase.instance.ref("hives").keepSynced(true);

    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    
    // Initialize notification services
    NotificationService.initialize().catchError((e) => debugPrint("Notification Init Error: $e"));
  } catch (e) {
    debugPrint("Firebase init error: $e");
  }

  runApp(const SmartBeeApp());
}

class SmartBeeApp extends StatefulWidget {
  const SmartBeeApp({super.key});

  static SmartBeeAppState? of(BuildContext context) => context.findAncestorStateOfType<SmartBeeAppState>();

  @override
  State<SmartBeeApp> createState() => SmartBeeAppState();
}

class SmartBeeAppState extends State<SmartBeeApp> {
  ThemeMode _themeMode = ThemeMode.light;
  Locale _locale = const Locale('en'); // Default to English for the project

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      // Default to 'light' theme
      _themeMode = (prefs.getString('theme_mode') ?? 'light') == 'dark' ? ThemeMode.dark : ThemeMode.light;
      
      // Default to 'en' (English) on first run
      final String? savedLang = prefs.getString('language_code');
      if (savedLang == null) {
        _locale = const Locale('en');
        // We don't necessarily need to save it immediately, 
        // but it ensures the first-run experience is English.
      } else {
        _locale = Locale(savedLang);
      }
    });
  }

  void changeTheme(ThemeMode themeMode) async {
    setState(() => _themeMode = themeMode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme_mode', themeMode == ThemeMode.dark ? 'dark' : 'light');
  }

  void changeLocale(Locale locale) async {
    setState(() => _locale = locale);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language_code', locale.languageCode);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Smart Bee',
      themeMode: _themeMode,
      
      // Light Theme
      theme: ThemeData(
        useMaterial3: true,
        primaryColor: AppColors.primary,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary, 
          brightness: Brightness.light,
          primary: AppColors.primary,
          surface: AppColors.backgroundLight,
        ),
        scaffoldBackgroundColor: AppColors.backgroundLight,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(color: Colors.black87, fontSize: 22, fontWeight: FontWeight.bold),
          iconTheme: IconThemeData(color: Colors.black87),
        ),
        cardTheme: CardThemeData(
          elevation: 2,
          shadowColor: Colors.black.withOpacity(0.05),
          color: Colors.white,
          surfaceTintColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
            side: BorderSide(color: Colors.black.withOpacity(0.05), width: 1),
          ),
          clipBehavior: Clip.antiAlias,
        ),
      ),
      
      // Dark Theme
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        primaryColor: AppColors.primary,
        scaffoldBackgroundColor: const Color(0xFF121212),
        cardColor: const Color(0xFF1E1E1E),
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary, 
          brightness: Brightness.dark,
          primary: AppColors.primary,
          surface: const Color(0xFF1E1E1E),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
          iconTheme: IconThemeData(color: Colors.white),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          color: const Color(0xFF1E1E1E),
          surfaceTintColor: const Color(0xFF1E1E1E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
            side: BorderSide(color: Colors.white.withOpacity(0.08), width: 1),
          ),
          clipBehavior: Clip.antiAlias,
        ),
      ),
      
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en'), Locale('ar')],
      locale: _locale,
      home: const MainDashboard(),
    );
  }
}
