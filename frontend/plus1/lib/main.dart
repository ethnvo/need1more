import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:plus1/event_screen.dart';
import 'package:plus1/firebase_test.dart'; // Import the test screen
import 'firebase_options.dart'; // your generated firebase config
import 'package:plus1/home_screen.dart'; // your home screen
import 'package:google_fonts/google_fonts.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Log Firebase connection attempt
  print("DEBUG: Initializing Firebase with options: ${DefaultFirebaseOptions.currentPlatform}");
  
  try {
    await Firebase.initializeApp(
      name: 'Plus1', // Use consistent name
      options: DefaultFirebaseOptions.currentPlatform,
    );
    
    // Log Firebase initialization result
    print("DEBUG: Firebase initialized successfully: ${Firebase.app().name}");
    print("DEBUG: Firebase database URL: ${Firebase.app().options.databaseURL}");
  } catch (e) {
    print("ERROR initializing Firebase: $e");
    
    // Try without name parameter in case it's already initialized
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      print("DEBUG: Firebase initialized without name parameter: ${Firebase.app().name}");
    } catch (fallbackError) {
      print("ERROR in fallback Firebase init: $fallbackError");
    }
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  
  static const Color primaryBlue = Color(0xFF4E96CC);
  static const Color accentYellow = Color(0xFFFFE260);
  
  @override
  Widget build(BuildContext context) {
   return MaterialApp(
      title: 'Plus1',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: primaryBlue,
          primary: primaryBlue,
          secondary: accentYellow,
          tertiary: Colors.white,
          brightness: Brightness.light,
        ),
        // Use Google Fonts for Poppins
        textTheme: GoogleFonts.poppinsTextTheme(Theme.of(context).textTheme),
        // Card theme
        cardTheme: CardTheme(
          elevation: 5,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          shadowColor: Colors.black38,
        ),
        // Elevated button theme
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: accentYellow,
            foregroundColor: Colors.black87,
            elevation: 4,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            textStyle: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
        // Input decoration theme
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: primaryBlue, width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          hintStyle: const TextStyle(color: Colors.black38),
          labelStyle: const TextStyle(color: Colors.black54),
        ),
        // App bar theme
        appBarTheme: AppBarTheme(
          backgroundColor: primaryBlue,
          foregroundColor: Colors.white,
          elevation: 0,
          titleTextStyle: GoogleFonts.poppins(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        // Tab bar theme
        tabBarTheme: const TabBarTheme(
          labelColor: accentYellow,
          unselectedLabelColor: Colors.white70,
          indicatorColor: accentYellow,
          indicatorSize: TabBarIndicatorSize.label,
          labelStyle: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
          unselectedLabelStyle: TextStyle(
            fontSize: 16,
          ),
        ),
      ),
      // For testing, temporarily use the Firebase test screen
      home: const HomeScreen(),
    );
  }
}
