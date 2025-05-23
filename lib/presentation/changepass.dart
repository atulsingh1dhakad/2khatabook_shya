import 'dart:async';
import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'loginscreen.dart';

class ChangePass extends StatefulWidget {
  const ChangePass({super.key});

  @override
  State<ChangePass> createState() => _ChangePassState();
}

class _ChangePassState extends State<ChangePass> {
  final TextEditingController currentPassController = TextEditingController();
  final TextEditingController newPassController = TextEditingController();
  final TextEditingController repeatNewPassController = TextEditingController();

  bool isLoading = false;
  bool _showCurrent = false;
  bool _showNew = false;
  bool _showRepeat = false;

  Future<void> _changePassword() async {
    final oldPassword = currentPassController.text.trim();
    final newPassword = newPassController.text.trim();
    final confirmPassword = repeatNewPassController.text.trim();

    if (oldPassword.isEmpty || newPassword.isEmpty || confirmPassword.isEmpty) {
      _showSnackBar("Please fill all fields");
      return;
    }
    if (newPassword != confirmPassword) {
      _showSnackBar("New passwords do not match");
      return;
    }

    setState(() {
      isLoading = true;
    });

    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? authToken = prefs.getString("auth_token");

    if (authToken == null || authToken.isEmpty) {
      _showSnackBar("Authentication error. Please log in again.");
      setState(() {
        isLoading = false;
      });
      return;
    }

    final url = Uri.parse("http://account.galaxyex.xyz/v1/user/api//user/change-password");
    final body = jsonEncode({
      "oldPassword": oldPassword,
      "newPassword": newPassword,
      "confirmPassword": confirmPassword,
    });

    try {
      final res = await http.post(
        url,
        headers: {
          "Authkey": authToken,
          "Content-Type": "application/json",
        },
        body: body,
      );

      final data = jsonDecode(res.body);

      if (res.statusCode == 200 && data["meta"]?["status"] == true) {
        setState(() {
          isLoading = false;
        });
        _showLogoutDialog();
      } else {
        setState(() {
          isLoading = false;
        });
        String msg = data["meta"]?["msg"] ?? "Failed to change password";
        _showSnackBar(msg);
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      _showSnackBar("Error: ${e.toString()}");
    }
  }

  void _showSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        Timer(const Duration(seconds: 15), () {
          if (Navigator.canPop(context)) {
            Navigator.of(context).pop();
            _logoutAndNavigate();
          }
        });
        return AlertDialog(
          title: const Text("Password Changed"),
          content: const Text("Your password has been changed. Please relogin."),
          actions: [
            TextButton(
              child: const Text("OK"),
              onPressed: () {
                Navigator.of(context).pop();
                _logoutAndNavigate();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _logoutAndNavigate() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove("auth_token");
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const EmailLoginScreen()),
          (route) => false,
    );
  }

  Widget _passwordField({
    required TextEditingController controller,
    required String label,
    required String placeholder,
    required bool showPassword,
    required VoidCallback onToggle,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 16,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Stack(
          alignment: Alignment.centerRight,
          children: [
            CupertinoTextField(
              controller: controller,
              placeholder: placeholder,
              obscureText: !showPassword,
              padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 12),
              style: const TextStyle(fontSize: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.black12, width: 1.2),
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            IconButton(
              icon: Icon(
                showPassword ? Icons.visibility_off : Icons.visibility,
                color: Colors.grey.shade600,
              ),
              onPressed: onToggle,
              splashRadius: 20,
              tooltip: showPassword ? "Hide password" : "View password",
            ),
          ],
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF205781),
      appBar: AppBar(
        backgroundColor: const Color(0xFF205781),
        leading: const BackButton(
          color: Colors.white,
        ),
        elevation: 0,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Column(
                    children: [
                      Image.asset(
                        'assets/images/passreset.png',
                        width: 250,
                        height: 250,
                      ),
                    ],
                  ),
                ),
                _passwordField(
                  controller: currentPassController,
                  label: "Current password",
                  placeholder: "Enter your current password",
                  showPassword: _showCurrent,
                  onToggle: () => setState(() => _showCurrent = !_showCurrent),
                ),
                _passwordField(
                  controller: newPassController,
                  label: "New password",
                  placeholder: "Enter a new password",
                  showPassword: _showNew,
                  onToggle: () => setState(() => _showNew = !_showNew),
                ),
                _passwordField(
                  controller: repeatNewPassController,
                  label: "Confirm new password",
                  placeholder: "Confirm new password",
                  showPassword: _showRepeat,
                  onToggle: () => setState(() => _showRepeat = !_showRepeat),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: isLoading
                      ? const Center(child: CircularProgressIndicator(color: Colors.white))
                      : CupertinoButton(
                    color: const Color(0xFF2196F3),
                    borderRadius: BorderRadius.circular(6),
                    child: const Text(
                      "Change password",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w400,
                        color: Colors.white,
                      ),
                    ),
                    onPressed: _changePassword,
                  ),
                ),
                const SizedBox(height: 36),
              ],
            ),
          ),
        ),
      ),
    );
  }
}