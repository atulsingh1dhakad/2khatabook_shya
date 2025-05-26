import 'dart:async';
import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../presentation/loginscreen.dart';

// --- Color Theme Based On Image --- //
const Color kPrimaryBlue = Color(0xFF225B84); // AppBar and button border
const Color kButtonText = Color(0xFF225B84);
const Color kBackground = Colors.white;
const Color kButtonBorder = Color(0xFF225B84);
const double kButtonRadius = 8;

class SecurityPinScreen extends StatefulWidget {
  const SecurityPinScreen({super.key});

  @override
  State<SecurityPinScreen> createState() => _SecurityPinScreenState();
}

class _SecurityPinScreenState extends State<SecurityPinScreen> {
  final TextEditingController pinController = TextEditingController();

  bool isLoading = false;
  bool _showPin = false;
  bool _securityEnabled = false;

  void _toggleSecurity(bool value) {
    setState(() {
      _securityEnabled = value;
    });
    // Optionally, persist the security status or perform other logic here.
    // For example, you could save to SharedPreferences:
    // SharedPreferences prefs = await SharedPreferences.getInstance();
    // prefs.setBool("security_enabled", value);
  }

  Future<void> _createPin() async {
    final pin = pinController.text.trim();

    if (pin.isEmpty) {
      _showSnackBar("Please enter a PIN");
      return;
    }
    if (pin.length < 4 || pin.length > 6 || int.tryParse(pin) == null) {
      _showSnackBar("PIN must be a 4-6 digit number");
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

    // Use your real API endpoint for creating PIN (replace the URL below)
    final url = Uri.parse("http://account.galaxyex.xyz/v1/user/api/user/create-pin");
    final body = jsonEncode({
      "pin": pin,
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
        String msg = data["meta"]?["msg"] ?? "Failed to create PIN";
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
          title: const Text("PIN Created"),
          content: const Text("Your security PIN has been set. Please relogin."),
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

  Widget _pinField({
    required TextEditingController controller,
    required String label,
    required String placeholder,
    required bool showPin,
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
                obscureText: !showPin,
                keyboardType: TextInputType.number,
                maxLength: 6,
                padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 12),
                style: const TextStyle(fontSize: 16, letterSpacing: 7),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: kButtonBorder, width: 1.4),
                  borderRadius: BorderRadius.circular(kButtonRadius),
                ),
              ),
              IconButton(
                icon: Icon(
                  showPin ? Icons.visibility_off : Icons.visibility,
                  color: kPrimaryBlue,
                ),
                onPressed: onToggle,
                splashRadius: 20,
                tooltip: showPin ? "Hide PIN" : "View PIN",
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _securitySwitch() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Security is ',
          style: const TextStyle(
            fontSize: 17,
            color: kPrimaryBlue,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          _securityEnabled ? 'ON' : 'OFF',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: _securityEnabled ? Colors.green : Colors.red,
          ),
        ),
        const SizedBox(width: 14),
        Switch(
          value: _securityEnabled,
          activeColor: Colors.green,
          inactiveThumbColor: Colors.red,
          inactiveTrackColor: Colors.red[200],
          onChanged: _toggleSecurity,
        ),
      ],
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
        title: const Text(
          "Security Number",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
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
                const SizedBox(height: 16),
                _securitySwitch(),
                const SizedBox(height: 30),
                _pinField(
                  controller: pinController,
                  label: "Security Number",
                  placeholder: "Enter your Number",
                  showPin: _showPin,
                  onToggle: () => setState(() => _showPin = !_showPin),
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
                      backgroundColor: kPrimaryBlue,
                      side: const BorderSide(color: kPrimaryBlue, width: 1.8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(kButtonRadius),
                      ),
                      textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                    ),
                    onPressed: _createPin,
                    child: const Text("Create Security Number"),
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