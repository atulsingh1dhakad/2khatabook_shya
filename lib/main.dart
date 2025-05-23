import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shya_khatabook/presentation/homescreen.dart';
import 'package:shya_khatabook/presentation/loginscreen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: EntryGate(),
    );
  }
}

class EntryGate extends StatefulWidget {
  const EntryGate({super.key});

  @override
  State<EntryGate> createState() => _EntryGateState();
}

class _EntryGateState extends State<EntryGate> {
  @override
  void initState() {
    super.initState();
    _decideNavigation();
  }

  Future<void> _decideNavigation() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    // Detect if app is opened for the first time
    bool isFirstOpen = prefs.getBool('is_first_open') ?? true;

    // If first open, set the flag to false and show login screen
    if (isFirstOpen) {
      await prefs.setBool('is_first_open', false);
      _pushReplace(const EmailLoginScreen());
      return;
    }

    // Check for valid token
    String? token = prefs.getString('auth_token');
    if (token != null && token.isNotEmpty) {
      _pushReplace(const HomeScreen());
    } else {
      _pushReplace(const EmailLoginScreen());
    }
  }

  void _pushReplace(Widget screen) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => screen),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}