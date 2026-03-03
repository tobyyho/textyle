import 'package:flutter/material.dart';
import 'screens/app_shell.dart';

void main() {
  runApp(const TextyleApp());
}

class TextyleApp extends StatelessWidget {
  const TextyleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Textyle',
      theme: ThemeData(
  useMaterial3: true,
  scaffoldBackgroundColor: const Color(0xFFF7F1F1), // warm blush background
  fontFamily: null,
  colorScheme: ColorScheme.fromSeed(
    seedColor: const Color(0xFF8E4B5A), // your Textyle mauve
    brightness: Brightness.light,
  ),
),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool loggedIn = false;

  @override
  Widget build(BuildContext context) {
    return loggedIn
        ? AppShell(onLogout: () => setState(() => loggedIn = false))
        : LoginScreen(onLogin: () => setState(() => loggedIn = true));
  }
}

class LoginScreen extends StatefulWidget {
  final VoidCallback onLogin;
  const LoginScreen({super.key, required this.onLogin});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  bool isSignUp = false;

  @override
  void dispose() {
    emailCtrl.dispose();
    passCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 20),
                  const Text(
                    'Textyle',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 36, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isSignUp ? 'Create your account' : 'Welcome back',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 28),

                  TextField(
                    controller: emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: passCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 18),

                  FilledButton(
                    onPressed: widget.onLogin, // demo: logs in instantly
                    child: Text(isSignUp ? 'Sign Up' : 'Log In'),
                  ),

                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: () => setState(() => isSignUp = !isSignUp),
                    child: Text(
                      isSignUp
                          ? 'Already have an account? Log in'
                          : "Don't have an account? Sign up",
                    ),
                  ),

                  const SizedBox(height: 10),
                  Text(
                    'Demo only: no real authentication yet.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade600),
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

class HomeScreen extends StatelessWidget {
  final VoidCallback onLogout;
  const HomeScreen({super.key, required this.onLogout});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Textyle'),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: onLogout,
            icon: const Icon(Icons.logout),
            tooltip: 'Log out',
          ),
        ],
      ),
      body: const Center(
        child: Text('Home (next we build Inventory + Outfit Picker)'),
      ),
    );
  }
}