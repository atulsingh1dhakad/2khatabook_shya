import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '/presentation/homescreen.dart';
import 'presentation/loginscreen.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'security/calciscreen.dart';

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
      // --------- TOKEN EXPIRY CHECK ADDED HERE ----------
      int? expiryTimestamp = prefs.getInt('token_expiry'); // Store expiry as epoch seconds
      if (expiryTimestamp != null) {
        final now = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
        if (now >= expiryTimestamp) {
          // Token expired, clear token and redirect to login
          await prefs.remove('auth_token');
          await prefs.remove('token_expiry');
          _pushReplace(const EmailLoginScreen());
          return;
        }
      }
      // ---------------------------------------------------

      // Check for security number (active)
      bool isSecurityActive = await _checkSecurityActive(token);
      if (isSecurityActive) {
        _pushReplace(const CustomCalculatorScreen());
      } else {
        _pushReplace(const HomeScreen());
      }
    } else {
      _pushReplace(const EmailLoginScreen());
    }
  }

  Future<bool> _checkSecurityActive(String token) async {
    try {
      final url = Uri.parse("http://account.galaxyex.xyz/v1/user/api/setting/get-security");
      final res = await http.get(
        url,
        headers: {
          "Authkey": token,
          "Content-Type": "application/json",
        },
      );

      debugPrint("Security API status: ${res.statusCode}");
      debugPrint("Security API body: ${res.body}");

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        debugPrint("Security API data: $data");
        if (data["meta"]?["status"] == true && data["data"] != null) {
          debugPrint("Security isActive: ${data["data"]["isActive"]}");
          return data["data"]["isActive"] == true;
        }
      }
    } catch (e) {
      debugPrint("Security check error: $e");
    }
    return false;
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