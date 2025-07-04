import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../LIST_LANG.dart';
import 'homescreen.dart';

const String loginAuthUrl = "http://account.galaxyex.xyz/v1/user/api//user/login";

class EmailLoginScreen extends StatefulWidget {
  const EmailLoginScreen({super.key});

  @override
  State<EmailLoginScreen> createState() => _EmailLoginScreenState();
}

class _EmailLoginScreenState extends State<EmailLoginScreen> {
  final TextEditingController _loginIdController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;

  Future<void> _handleLoginSuccess(Map<String, dynamic> user) async {
    final prefs = await SharedPreferences.getInstance();

    // Prefer language from user profile if available, else default to 'en'
    String langCode = 'en';
    if (user['language'] != null && user['language'].toString().isNotEmpty) {
      langCode = user['language'].toString();
    } else {
      // Try to read last used from prefs, fallback to 'en'
      langCode = prefs.getString('app_language') ?? 'en';
    }

    await prefs.setString('app_language', langCode);
    await AppStrings.setLanguage(langCode);
  }

  void _sendLoginRequest(String loginId, String password) async {
    if (loginId.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter Login ID and password')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await http.post(
        Uri.parse(loginAuthUrl),
        headers: {"Content-Type": "application/json"},
        body: json.encode({"loginId": loginId, "password": password}),
      );

      print("Login response status: ${response.statusCode}");
      print("Login response body: ${response.body}");

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['meta']?['status'] == true && data['data']?['token'] != null) {
          String token = data['data']['token'];
          SharedPreferences prefs = await SharedPreferences.getInstance();
          await prefs.setString("auth_token", token);

          // Save userId, userType, and userName from response
          final user = data['data']['user'];
          if (user != null) {
            await prefs.setString("userId", user["userId"].toString());
            await prefs.setString("userType", user["userType"].toString());
            await prefs.setString("userName", user["name"].toString());
            print("Saved userId: ${user["userId"]}, userType: ${user["userType"]}, userName: ${user["name"]}");

            // Set language after successful login
            await _handleLoginSuccess(user);
          } else {
            print("WARNING: User info not found in login response. Permission checks may fail.");
            // But still set language to 'en' so HomeScreen does not crash
            await AppStrings.setLanguage('en');
            await prefs.setString('app_language', 'en');
          }

          if (!mounted) return;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => HomeScreen()),
          );
        } else {
          final msg = data['meta']?['msg'] ?? "Login failed. Please try again.";
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(msg)),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('HTTP Error: ${response.statusCode}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 10, bottom: 10),
                child: Column(
                  children: [
                    Image.asset(
                      'assets/images/auth.png',
                      width: 350,
                      height: 350,
                    ),
                  ],
                ),
              ),
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(15.0),
                  child: Column(
                    children: [
                      const Text(
                        'Login',
                        style: TextStyle(
                          fontFamily: 'OpenSans',
                          fontSize: 20,
                          fontWeight: FontWeight.normal,
                          color: Color(0xff1A1A2E),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'For your Protection, Please Verify Your Identity',
                        style: GoogleFonts.openSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w300,
                          color: const Color(0xff1A1A2E),
                        ),
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: _loginIdController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          fillColor: Colors.white70,
                          filled: true,
                          prefixIcon: const Icon(Icons.mail, size: 20),
                          hintText: 'Login ID',
                          hintStyle: const TextStyle(fontWeight: FontWeight.w400),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Colors.grey),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: const BorderSide(color: Color(0xff2D486C)),
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: _passwordController,
                        keyboardType: TextInputType.text,
                        obscureText: true,
                        decoration: InputDecoration(
                          fillColor: Colors.white70,
                          filled: true,
                          prefixIcon: const Icon(Icons.lock, size: 20),
                          hintText: 'Password',
                          hintStyle: const TextStyle(fontWeight: FontWeight.w400),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Colors.grey),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: const BorderSide(color: Color(0xff2D486C)),
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      const SizedBox(height: 30),
                      ElevatedButton(
                        onPressed: _isLoading
                            ? null
                            : () => _sendLoginRequest(
                          _loginIdController.text.trim(),
                          _passwordController.text.trim(),
                        ),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(320, 54),
                          shadowColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          backgroundColor: const Color(0xff0A66C2),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          textStyle: const TextStyle(fontSize: 20),
                        ),
                        child: _isLoading
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text(
                          'Login',
                          style: TextStyle(color: Colors.white, fontSize: 14),
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
    );
  }
}