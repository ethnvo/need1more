import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:plus1/event_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final phoneController = TextEditingController();
  final databaseRef = FirebaseDatabase.instance.ref();
  bool isLoading = false;
  bool isRegisterMode = true;
  late AnimationController _logoController;

  @override
  void initState() {
    super.initState();
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    _logoController.forward();
  }

  @override
  void dispose() {
    _logoController.dispose();
    emailController.dispose();
    passwordController.dispose();
    phoneController.dispose();
    super.dispose();
  }

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
        MaterialPageRoute(builder: (context) => const EventScreen()),
      );
    } on FirebaseAuthException catch (e) {
      showMessage(e.message ?? 'Authentication failed');
    } finally {
      setState(() => isLoading = false);
    }
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFE0F7FA), Color.fromARGB(255, 25, 76, 229)], // nice teal gradient
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 40),
                  FadeTransition(
                    opacity: _logoController,
                    child: SizedBox(
                      height: 180,
                      child: Image.asset(
                        'assets/Logo-Square-Grad.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                  TextField(
                    controller: emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email (.edu)',
                      filled: true,
                      fillColor: Colors.white70,
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (isRegisterMode)
                    TextField(
                      controller: phoneController,
                      decoration: const InputDecoration(
                        labelText: 'Phone Number',
                        filled: true,
                        fillColor: Colors.white70,
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                  if (isRegisterMode) const SizedBox(height: 16),
                  TextField(
                    controller: passwordController,
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      filled: true,
                      fillColor: Colors.white70,
                      border: OutlineInputBorder(),
                    ),
                    obscureText: true,
                  ),
                  const SizedBox(height: 30),
                 isLoading
                ? const CircularProgressIndicator()
                : Container(
                    width: double.infinity,
                    height: 50,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFFFFD700), // gold
                          Color(0xFFFFB300), // deeper gold/orange
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ElevatedButton(
                      onPressed: handleAuth,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        isRegisterMode ? 'Register' : 'Login',
                        style: const TextStyle(fontSize: 18, color: Colors.black87),
                      ),
                    ),
                  ),

                                    
                  const SizedBox(height: 12),
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
                      style: const TextStyle(color: Colors.black87),
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
