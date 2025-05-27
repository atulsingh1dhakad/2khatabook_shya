import 'dart:async';
import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';

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
  bool _securityEnabled = false;
  bool _pinSaved = false;
  String? _errorMsg;
  int? _savedPin; // stores the fetched existing pin if any

  @override
  void initState() {
    super.initState();
    _loadSecurityStatus();
    _fetchSecurityPin(); // Try to fetch existing security pin on load
  }

  Future<String?> getAuthToken() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString("auth_token");
  }

  Future<void> _loadSecurityStatus() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    _securityEnabled = prefs.getBool("security_enabled") ?? false;
    setState(() {});
  }

  Future<void> _fetchSecurityPin() async {
    final authToken = await getAuthToken();
    if (authToken == null) return;

    final url = Uri.parse("http://account.galaxyex.xyz/v1/user/api/setting/get-security");
    try {
      final res = await http.get(
        url,
        headers: {
          "Authkey": authToken,
          "Content-Type": "application/json",
        },
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data["meta"]?["status"] == true && data["data"] != null) {
          setState(() {
            _savedPin = data["data"]["code"];
            _securityEnabled = data["data"]["isActive"] ?? false;
            _pinSaved = _savedPin != null;
            pinController.text = _savedPin?.toString() ?? "";
          });
        } else {
          // If there is no security pin, reset everything
          setState(() {
            _savedPin = null;
            _securityEnabled = false;
            _pinSaved = false;
            pinController.clear();
          });
        }
      }
    } catch (e) {
      // Optionally handle fetch errors, but do not show to user on load
      print("Fetch security pin error: $e");
    }
  }

  void _toggleSecurity(bool value) async {
    setState(() {
      _securityEnabled = value;
      _errorMsg = null;
      // If turning off, clear pin and UI
      if (!value) {
        pinController.clear();
        _pinSaved = false;
        _savedPin = null;
      }
    });
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setBool("security_enabled", value);

    // If turned off, remove security from backend
    if (!value) {
      await _removeSecurityPin();
      // Always re-fetch after attempting removal to sync with backend
      await _fetchSecurityPin();
    }
  }

  Future<void> _removeSecurityPin() async {
    final authToken = await getAuthToken();
    if (authToken == null) return;
    final url = Uri.parse("http://account.galaxyex.xyz/v1/user/api/setting/remove-security");
    try {
      // Use GET instead of POST as per your request
      final res = await http.get(
        url,
        headers: {
          "Authkey": authToken,
          "Content-Type": "application/json",
        },
      );
      print("Remove security response: ${res.statusCode}, ${res.body}");
      if (res.statusCode == 200) {
        setState(() {
          _savedPin = null;
          _pinSaved = false;
          pinController.clear();
        });
        _showSnackBar("Security number removed.");
      } else {
        setState(() {
          _errorMsg = "Failed to remove security code. Please try again.";
        });
        _showSnackBar("Failed to remove security code. Please try again.");
      }
    } catch (e) {
      print("Remove security exception: $e");
      setState(() {
        _errorMsg = "Failed to remove security code. Please try again.";
      });
      _showSnackBar("Failed to remove security code. Please try again.");
    }
  }

  Future<void> _savePin() async {
    setState(() {
      _errorMsg = null;
    });

    final pin = pinController.text.trim();

    if (pin.isEmpty || int.tryParse(pin) == null) {
      setState(() {
        _errorMsg = "Security number must be a number";
      });
      _showSnackBar("Security number must be a number");
      return;
    }

    // Limit to 19 digits (safe for 64-bit int backend)
    if (pin.length > 19) {
      setState(() {
        _errorMsg = "Security number is too long";
      });
      _showSnackBar("Security number is too long");
      return;
    }

    int parsedPin;
    try {
      parsedPin = int.parse(pin);
    } catch (e) {
      setState(() {
        _errorMsg = "Security number is invalid or too large";
      });
      _showSnackBar("Security number is invalid or too large");
      return;
    }

    setState(() {
      isLoading = true;
      _errorMsg = null;
    });

    String? authToken = await getAuthToken();

    if (authToken == null || authToken.isEmpty) {
      setState(() {
        isLoading = false;
        _errorMsg = "Authentication error. Please log in again.";
      });
      _showSnackBar("Authentication error. Please log in again.");
      return;
    }

    final url = Uri.parse("http://account.galaxyex.xyz/v1/user/api/setting/add-security");
    final body = jsonEncode({
      "isActive": _securityEnabled,
      "code": parsedPin,
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

      dynamic data;
      String serverMsg = "";
      try {
        data = jsonDecode(res.body);
        serverMsg = data["meta"]?["msg"]?.toString() ?? "";
      } catch (e) {
        serverMsg = "Invalid server response: ${res.body}";
      }

      print("API Response Status: ${res.statusCode}");
      print("API Response Body: ${res.body}");
      if (serverMsg.isNotEmpty) {
        print("API Error Message: $serverMsg");
      }

      if (res.statusCode == 200 && data?["meta"]?["status"] == true) {
        setState(() {
          isLoading = false;
          _pinSaved = true;
          _errorMsg = null;
          _savedPin = parsedPin;
        });
        _showSnackBar("Security number saved successfully.");
      } else {
        String errorDetail = "Failed to save security number";
        if (serverMsg.isNotEmpty) errorDetail = serverMsg;
        errorDetail += " (HTTP ${res.statusCode})";
        setState(() {
          isLoading = false;
          _errorMsg = errorDetail;
        });
        _showSnackBar(errorDetail);
      }
    } catch (e) {
      print("Exception during API call: $e");
      setState(() {
        isLoading = false;
        _errorMsg = "Error: ${e.toString()}";
      });
      _showSnackBar("Error: ${e.toString()}");
    }
  }

  void _showSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  Widget _pinField({
    required TextEditingController controller,
    required String label,
    required String placeholder,
    required bool enabled,
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
          CupertinoTextField(
            controller: controller,
            placeholder: placeholder,
            obscureText: false, // Always visible
            enabled: enabled,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 12),
            style: const TextStyle(fontSize: 16, letterSpacing: 7),
            decoration: BoxDecoration(
              color: enabled ? Colors.white : Colors.grey[200],
              border: Border.all(color: kButtonBorder, width: 1.4),
              borderRadius: BorderRadius.circular(kButtonRadius),
            ),
          ),
        ],
      ),
    );
  }

  Widget _securitySwitch() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          'Security is ',
          style: TextStyle(
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

  Widget _changePinButton() {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          foregroundColor: kPrimaryBlue,
          backgroundColor: Colors.white,
          side: const BorderSide(color: kPrimaryBlue, width: 1.8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(kButtonRadius),
          ),
          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
        ),
        onPressed: null, // No functionality yet
        child: const Text("Change your security number"),
      ),
    );
  }

  Widget _savePinButton() {
    return SizedBox(
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
        onPressed: _savePin,
        child: const Text("Save Security Number"),
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
                if (_securityEnabled && !_pinSaved)
                  Column(
                    children: [
                      _pinField(
                        controller: pinController,
                        label: "Security Number",
                        placeholder: "Enter your Number",
                        enabled: true,
                      ),
                      if (_errorMsg != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6.0),
                          child: Text(
                            _errorMsg!,
                            style: const TextStyle(color: Colors.red, fontSize: 15),
                          ),
                        ),
                      const SizedBox(height: 8),
                      _savePinButton(),
                    ],
                  ),
                if (_securityEnabled && _pinSaved)
                  Column(
                    children: [
                      if (_savedPin != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16.0),
                          child: Text(
                            "Your security code: $_savedPin",
                            style: const TextStyle(
                                color: kPrimaryBlue,
                                fontSize: 18,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      const SizedBox(height: 8),
                      _changePinButton(),
                    ],
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