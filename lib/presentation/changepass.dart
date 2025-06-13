import 'dart:async';
import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../LIST_LANG.dart';
import 'loginscreen.dart';

// --- Color Theme Based On Image --- //
const Color kPrimaryBlue = Color(0xFF225B84); // AppBar and button border
const Color kButtonText = Color(0xFF225B84);
const Color kBackground = Colors.white;
const Color kButtonBorder = Color(0xFF225B84);
const double kButtonRadius = 8;

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
      _showSnackBar(AppStrings.getString("fillAllFields"));
      return;
    }
    if (newPassword != confirmPassword) {
      _showSnackBar(AppStrings.getString("passwordsDoNotMatch"));
      return;
    }

    setState(() {
      isLoading = true;
    });

    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? authToken = prefs.getString("auth_token");

    if (authToken == null || authToken.isEmpty) {
      _showSnackBar(AppStrings.getString("authErrorRelogin"));
      setState(() {
        isLoading = false;
      });
      return;
    }

    final url = Uri.parse("http://account.galaxyex.xyz/v1/user/api/user/change-password");
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
        String msg = data["meta"]?["msg"] ?? AppStrings.getString("failedToChangePassword");
        _showSnackBar(msg);
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      _showSnackBar("${AppStrings.getString("error")}: ${e.toString()}");
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
          title: Text(AppStrings.getString("passwordChanged")),
          content: Text(AppStrings.getString("reloginPrompt")),
          actions: [
            TextButton(
              child: Text(AppStrings.getString("ok")),
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 18.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 16,
              color: kPrimaryBlue,
              fontWeight: FontWeight.w500,
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
                  border: Border.all(color: kButtonBorder, width: 1.4),
                  borderRadius: BorderRadius.circular(kButtonRadius),
                ),
              ),
              IconButton(
                icon: Icon(
                  showPassword ? Icons.visibility_off : Icons.visibility,
                  color: kPrimaryBlue,
                ),
                onPressed: onToggle,
                splashRadius: 20,
                tooltip: showPassword
                    ? AppStrings.getString("hidePassword")
                    : AppStrings.getString("viewPassword"),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        backgroundColor: kPrimaryBlue,
        leading: const BackButton(
          color: Colors.white,
        ),
        elevation: 0,
        title: Text(
          AppStrings.getString("changePassword"),
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
        ),
        centerTitle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(28),
          ),
        ),
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
                    ],
                  ),
                ),
                _passwordField(
                  controller: currentPassController,
                  label: AppStrings.getString("currentPassword"),
                  placeholder: AppStrings.getString("enterCurrentPassword"),
                  showPassword: _showCurrent,
                  onToggle: () => setState(() => _showCurrent = !_showCurrent),
                ),
                _passwordField(
                  controller: newPassController,
                  label: AppStrings.getString("newPassword"),
                  placeholder: AppStrings.getString("enterNewPassword"),
                  showPassword: _showNew,
                  onToggle: () => setState(() => _showNew = !_showNew),
                ),
                _passwordField(
                  controller: repeatNewPassController,
                  label: AppStrings.getString("confirmNewPassword"),
                  placeholder: AppStrings.getString("confirmNewPasswordPlaceholder"),
                  showPassword: _showRepeat,
                  onToggle: () => setState(() => _showRepeat = !_showRepeat),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: isLoading
                      ? const Center(child: CircularProgressIndicator(color: kPrimaryBlue))
                      : OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: Color(0xFF225B84),
                      side: const BorderSide(color: kPrimaryBlue, width: 1.8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(kButtonRadius),
                      ),
                      textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                    ),
                    onPressed: _changePassword,
                    child: Text(AppStrings.getString("changePasswordButton")),
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