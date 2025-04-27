import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart'; // <-- Needed for kIsWeb
import 'package:plus1/event_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Future<void> signInWithGoogle(BuildContext context) async {
    try {
      final googleSignIn = GoogleSignIn(
        clientId: kIsWeb
            ? '524201570404-jerkce5cm43j14ldhc6goo20u9p7ca0d.apps.googleusercontent.com'
            : null, // <-- Only set clientId on Web
      );

      print('Attempting Google Sign-In...');
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        print('Google Sign-In canceled by user.');
        return;
      }

      print('Google User selected: ${googleUser.email}');

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      print('Google authentication tokens received.');

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
      final user = userCredential.user;

      if (user == null) {
        print('Firebase User is null after sign-in.');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sign-in failed. Try again.')),
        );
        return;
      }

      print('User signed in successfully: ${user.email}');

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const EventScreen()),
      );
    } catch (e, stackTrace) {
      print('Sign-in error: $e');
      print('Stack trace: $stackTrace');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sign-in failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Welcome to Plus1!'),
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: () => signInWithGoogle(context),
          child: const Text('Sign in with Google'),
        ),
      ),
    );
  }
}
