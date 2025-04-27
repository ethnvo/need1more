import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Future<void> _handleGoogleSignIn() async {
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        print('User canceled the sign-in.');
        return;
      }
      print('User signed in: ${googleUser.email}');
    } catch (e) {
      print('Error during sign-in: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('MyPage')),
      body: Center(
        child: FloatingActionButton.extended(
          onPressed: _handleGoogleSignIn,
          icon: const Icon(Icons.security),
          label: const Text('Sign in with Google'),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
        ),
      ),
    );
  }
}
