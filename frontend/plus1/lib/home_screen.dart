import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:plus1/event_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final phoneController = TextEditingController();
  final databaseRef = FirebaseDatabase.instance.ref();
  bool isLoading = false;
  bool isRegisterMode = true; // 🔥 Toggle between register and login

  Future<void> handleAuth() async {
    setState(() {
      isLoading = true;
    });

    final email = emailController.text.trim();
    final password = passwordController.text.trim();
    final phone = phoneController.text.trim();

    if (!email.endsWith('.edu')) {
      showMessage('Email must end with .edu');
      setState(() {
        isLoading = false;
      });
      return;
    }
    if (password.length < 6) {
      showMessage('Password must be at least 6 characters');
      setState(() {
        isLoading = false;
      });
      return;
    }
    if (isRegisterMode && (phone.isEmpty || phone.length < 10)) {
      showMessage('Enter a valid phone number');
      setState(() {
        isLoading = false;
      });
      return;
    }

    try {
      if (isRegisterMode) {
        final phoneQuery = await databaseRef
            .child('users')
            .orderByChild('phone')
            .equalTo(phone)
            .limitToFirst(1)
            .get();

        if (phoneQuery.exists) {
          showMessage('Phone number already registered');
          setState(() {
            isLoading = false;
          });
          return;
        }

        UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );

        await databaseRef.child('users/${userCredential.user!.uid}').set({
          'email': email,
          'phone': phone,
        });
      } else {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const EventScreen()),
      );
    } on FirebaseAuthException catch (e) {
      showMessage(e.message ?? 'Authentication failed');
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isRegisterMode ? 'Register' : 'Login'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: emailController,
              decoration: const InputDecoration(labelText: 'Email (.edu)'),
            ),
            if (isRegisterMode)
              TextField(
                controller: phoneController,
                decoration: const InputDecoration(labelText: 'Phone Number'),
                keyboardType: TextInputType.phone,
              ),
            TextField(
              controller: passwordController,
              decoration: const InputDecoration(labelText: 'Password'),
              obscureText: true,
            ),
            const SizedBox(height: 20),
            isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: isLoading ? null : handleAuth,
                    child: Text(isRegisterMode ? 'Register' : 'Login'),
                  ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () {
                setState(() {
                  isRegisterMode = !isRegisterMode;
                  emailController.clear();
                  passwordController.clear();
                  phoneController.clear();
                });
              },
              child: Text(
                isRegisterMode
                    ? 'Already have an account? Login'
                    : 'Need an account? Register',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
