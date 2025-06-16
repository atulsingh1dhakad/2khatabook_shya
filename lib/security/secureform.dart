import 'dart:async';
import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import '../LIST_LANG.dart';

// --- Color Theme Based On Image --- //
const Color kPrimaryBlue = Color(0xFF225B84);
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
  final TextEditingController changePinController = TextEditingController();

  bool isLoading = false;
  bool isChanging = false;
  bool _securityEnabled = false;
  bool _pinSaved = false;
  String? _errorMsg;
  String? _changeErrorMsg;
  int? _savedPin; // stores the fetched existing pin if any

  @override
  void initState() {
    super.initState();
    _loadSecurityStatus();
    _fetchSecurityPin();
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
          setState(() {
            _savedPin = null;
            _securityEnabled = false;
            _pinSaved = false;
            pinController.clear();
          });
        }
      }
    } catch (_) {}
  }

  void _toggleSecurity(bool value) async {
    setState(() {
      _securityEnabled = value;
      _errorMsg = null;
      if (!value) {
        pinController.clear();
        changePinController.clear();
        _pinSaved = false;
        _savedPin = null;
      }
    });
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setBool("security_enabled", value);

    if (!value) {
      await _removeSecurityPin();
      await _fetchSecurityPin();
    }
  }

  Future<void> _removeSecurityPin() async {
    final authToken = await getAuthToken();
    if (authToken == null) return;
    final url = Uri.parse("http://account.galaxyex.xyz/v1/user/api/setting/remove-security");
    try {
      final res = await http.get(
        url,
        headers: {
          "Authkey": authToken,
          "Content-Type": "application/json",
        },
      );
      if (res.statusCode == 200) {
        setState(() {
          _savedPin = null;
          _pinSaved = false;
          pinController.clear();
          changePinController.clear();
        });
        _showSnackBar(AppStrings.getString("securityRemoved"));
      } else {
        setState(() {
          _errorMsg = AppStrings.getString("failedToRemoveSecurity");
        });
        _showSnackBar(AppStrings.getString("failedToRemoveSecurity"));
      }
    } catch (_) {
      setState(() {
        _errorMsg = AppStrings.getString("failedToRemoveSecurity");
      });
      _showSnackBar(AppStrings.getString("failedToRemoveSecurity"));
    }
  }

  Future<void> _savePin({bool isChange = false}) async {
    setState(() {
      if (isChange) {
        _changeErrorMsg = null;
        isChanging = true;
      } else {
        _errorMsg = null;
        isLoading = true;
      }
    });

    final pin = isChange ? changePinController.text.trim() : pinController.text.trim();

    if (pin.isEmpty || int.tryParse(pin) == null) {
      setState(() {
        if (isChange) {
          _changeErrorMsg = AppStrings.getString("securityNumberMustBeNumber");
          isChanging = false;
        } else {
          _errorMsg = AppStrings.getString("securityNumberMustBeNumber");
          isLoading = false;
        }
      });
      _showSnackBar(AppStrings.getString("securityNumberMustBeNumber"));
      return;
    }

    if (pin.length > 19) {
      setState(() {
        if (isChange) {
          _changeErrorMsg = AppStrings.getString("securityNumberTooLong");
          isChanging = false;
        } else {
          _errorMsg = AppStrings.getString("securityNumberTooLong");
          isLoading = false;
        }
      });
      _showSnackBar(AppStrings.getString("securityNumberTooLong"));
      return;
    }

    int parsedPin;
    try {
      parsedPin = int.parse(pin);
    } catch (_) {
      setState(() {
        if (isChange) {
          _changeErrorMsg = AppStrings.getString("securityNumberInvalidOrLarge");
          isChanging = false;
        } else {
          _errorMsg = AppStrings.getString("securityNumberInvalidOrLarge");
          isLoading = false;
        }
      });
      _showSnackBar(AppStrings.getString("securityNumberInvalidOrLarge"));
      return;
    }

    String? authToken = await getAuthToken();

    if (authToken == null || authToken.isEmpty) {
      setState(() {
        if (isChange) {
          _changeErrorMsg = AppStrings.getString("authErrorRelogin");
          isChanging = false;
        } else {
          _errorMsg = AppStrings.getString("authErrorRelogin");
          isLoading = false;
        }
      });
      _showSnackBar(AppStrings.getString("authErrorRelogin"));
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
      } catch (_) {
        serverMsg = "Invalid server response: ${res.body}";
      }

      if (res.statusCode == 200 && data?["meta"]?["status"] == true) {
        setState(() {
          isLoading = false;
          isChanging = false;
          _pinSaved = true;
          _errorMsg = null;
          _changeErrorMsg = null;
          _savedPin = parsedPin;
          pinController.text = parsedPin.toString();
          changePinController.clear();
        });
        _showSnackBar(isChange
            ? AppStrings.getString("securityNumberChanged")
            : AppStrings.getString("saveSecurityNumber"));
      } else {
        String errorDetail = AppStrings.getString("failedToSaveSecurityNumber");
        if (serverMsg.isNotEmpty) errorDetail = serverMsg;
        errorDetail += " (HTTP ${res.statusCode})";
        setState(() {
          if (isChange) {
            _changeErrorMsg = errorDetail;
            isChanging = false;
          } else {
            _errorMsg = errorDetail;
            isLoading = false;
          }
        });
        _showSnackBar(errorDetail);
      }
    } catch (e) {
      setState(() {
        if (isChange) {
          _changeErrorMsg = "${AppStrings.getString("error")}: ${e.toString()}";
          isChanging = false;
        } else {
          _errorMsg = "${AppStrings.getString("error")}: ${e.toString()}";
          isLoading = false;
        }
      });
      _showSnackBar("${AppStrings.getString("error")}: ${e.toString()}");
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
            obscureText: false,
            enabled: enabled,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 12),
            style: const TextStyle(fontSize: 16, letterSpacing: 0),
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
        Text(
          '${AppStrings.getString("security")} ',
          style: const TextStyle(
            fontSize: 17,
            color: kPrimaryBlue,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          _securityEnabled
              ? AppStrings.getString("on")
              : AppStrings.getString("off"),
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

  Widget _changePinSection() {
    return Column(
      children: [
        _pinField(
          controller: changePinController,
          label: AppStrings.getString("changeSecurityNumber"),
          placeholder: AppStrings.getString("enterNewSecurityNumber"),
          enabled: true,
        ),
        if (_changeErrorMsg != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6.0),
            child: Text(
              _changeErrorMsg!,
              style: const TextStyle(color: Colors.red, fontSize: 15),
            ),
          ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: isChanging
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
            onPressed: () => _savePin(isChange: true),
            child: Text(AppStrings.getString("changeSecurityNumber")),
          ),
        ),
      ],
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
        onPressed: () => _savePin(),
        child: Text(AppStrings.getString("saveSecurityNumber")),
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
          AppStrings.getString("securityNumber"),
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
                const SizedBox(height: 16),
                _securitySwitch(),
                const SizedBox(height: 30),
                if (_securityEnabled && !_pinSaved)
                  Column(
                    children: [
                      _pinField(
                        controller: pinController,
                        label: AppStrings.getString("securityNumber"),
                        placeholder: AppStrings.getString("enterNewSecurityNumber"),
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
                            "${AppStrings.getString("yourSecurityCode")}: $_savedPin",
                            style: const TextStyle(
                                color: kPrimaryBlue,
                                fontSize: 18,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      _changePinSection(),
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