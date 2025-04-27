import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:plus1/event_screen.dart';
import 'firebase_options.dart'; // your generated firebase config
import 'package:plus1/home_screen.dart'; // your home screen

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Plus1 App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: EventScreen(), // <-- starts at HomeScreen
    );
  }
}
