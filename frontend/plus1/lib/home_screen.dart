import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:plus1/event_tabs_screen.dart';

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
  bool isRegisterMode = true;
  static const Color primaryBlue = Color(0xFF4E96CC);
  static const Color accentYellow = Color(0xFFFFE260);

  Future<void> handleAuth() async {
    setState(() => isLoading = true);

    final email = emailController.text.trim();
    final password = passwordController.text.trim();
    final phone = phoneController.text.trim();

    if (!email.endsWith('.edu')) {
      showMessage('Email must end with .edu');
      setState(() => isLoading = false);
      return;
    }
    if (password.length < 6) {
      showMessage('Password must be at least 6 characters');
      setState(() => isLoading = false);
      return;
    }
    if (isRegisterMode && (phone.isEmpty || phone.length < 10)) {
      showMessage('Enter a valid phone number');
      setState(() => isLoading = false);
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
          setState(() => isLoading = false);
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
        MaterialPageRoute(builder: (context) => const EventTabsScreen()),
      );
    } on FirebaseAuthException catch (e) {
      showMessage(e.message ?? 'Authentication failed');
    } finally {
      setState(() => isLoading = false);
    }
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: primaryBlue,
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: MediaQuery.of(context).size.width,
        height: MediaQuery.of(context).size.height,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [primaryBlue, Color(0xFF3E7CAB)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                children: [
                  const SizedBox(height: 40),
                  // Logo with yellow accent
                  Container(
                    height: 120,
                    width: 120,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 15,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(4),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: accentYellow, width: 3),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Image.asset(
                          'assets/Logo-Square-Grad.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  // App name
                  Text(
                    'PLUS ONE',
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 1.5,
                      shadows: [
                        Shadow(
                          color: Colors.black.withOpacity(0.2),
                          offset: const Offset(0, 2),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    isRegisterMode ? 'Create your account' : 'Welcome back',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                  const SizedBox(height: 40),
                  // Auth form card
                  Card(
                    elevation: 10,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    shadowColor: Colors.black26,
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextField(
                            controller: emailController,
                            decoration: InputDecoration(
                              labelText: 'Email (.edu)',
                              prefixIcon: const Icon(Icons.email, color: primaryBlue),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              fillColor: Colors.white,
                              labelStyle: const TextStyle(color: primaryBlue),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: primaryBlue, width: 2),
                              ),
                            ),
                            keyboardType: TextInputType.emailAddress,
                          ),
                          const SizedBox(height: 16),
                          if (isRegisterMode)
                            TextField(
                              controller: phoneController,
                              decoration: InputDecoration(
                                labelText: 'Phone Number',
                                prefixIcon: const Icon(Icons.phone, color: primaryBlue),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                filled: true,
                                fillColor: Colors.white,
                                labelStyle: const TextStyle(color: primaryBlue),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: primaryBlue, width: 2),
                                ),
                              ),
                              keyboardType: TextInputType.phone,
                            ),
                          if (isRegisterMode) const SizedBox(height: 16),
                          TextField(
                            controller: passwordController,
                            decoration: InputDecoration(
                              labelText: 'Password',
                              prefixIcon: const Icon(Icons.lock, color: primaryBlue),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              fillColor: Colors.white,
                              labelStyle: const TextStyle(color: primaryBlue),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: primaryBlue, width: 2),
                              ),
                            ),
                            obscureText: true,
                          ),
                          const SizedBox(height: 30),
                          isLoading
                              ? const Center(child: CircularProgressIndicator(color: primaryBlue))
                              : ElevatedButton(
                                  onPressed: isLoading ? null : handleAuth,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: accentYellow,
                                    foregroundColor: Colors.black87,
                                    padding: const EdgeInsets.symmetric(vertical: 15),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    elevation: 5,
                                  ),
                                  child: Text(
                                    isRegisterMode ? 'REGISTER' : 'LOGIN',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                          const SizedBox(height: 16),
                          Center(
                            child: TextButton(
                              onPressed: () {
                                setState(() {
                                  isRegisterMode = !isRegisterMode;
                                  emailController.clear();
                                  passwordController.clear();
                                  phoneController.clear();
                                });
                              },
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.white,
                              ),
                              child: Text(
                                isRegisterMode
                                    ? 'Already have an account? Login'
                                    : 'Need an account? Register',
                                style: const TextStyle(
                                  color: primaryBlue,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
