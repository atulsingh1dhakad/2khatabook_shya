import 'package:flutter/material.dart';
import 'package:flutter_simple_calculator/flutter_simple_calculator.dart';
import 'package:shya_khatabook/presentation/homescreen.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class SimpleCalculatorScreen extends StatefulWidget {
  const SimpleCalculatorScreen({Key? key}) : super(key: key);

  @override
  State<SimpleCalculatorScreen> createState() => _SimpleCalculatorScreenState();
}

class _SimpleCalculatorScreenState extends State<SimpleCalculatorScreen> {
  double _result = 0.0;
  int? _securityCode;
  bool _loading = true;
  String? _error;
  bool _unlocked = false; // To prevent multiple navigations

  @override
  void initState() {
    super.initState();
    _fetchSecurityCode();
  }

  Future<void> _fetchSecurityCode() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('auth_token');

    if (token == null || token.isEmpty) {
      setState(() {
        _loading = false;
        _error = "No auth token found.";
      });
      return;
    }

    try {
      final url = Uri.parse("http://account.galaxyex.xyz/v1/user/api/setting/get-security");
      final res = await http.get(
        url,
        headers: {
          "Authkey": token,
          "Content-Type": "application/json",
        },
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data["meta"]?["status"] == true && data["data"] != null) {
          setState(() {
            _securityCode = data["data"]["code"];
            _loading = false;
          });
        } else {
          setState(() {
            _loading = false;
            _error = "No security code found.";
          });
        }
      } else {
        setState(() {
          _loading = false;
          _error = "Failed to get security code. (${res.statusCode})";
        });
      }
    } catch (e) {
      setState(() {
        _loading = false;
        _error = "Error: $e";
      });
    }
  }

  void _checkAndNavigate(double value) {
    if (_securityCode == null || _unlocked) return;
    // Use a tolerance for floating point comparison
    if ((value - _securityCode!).abs() < 0.0001) {
      _unlocked = true; // Prevent multiple navigations
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Scaffold(
        body: Center(child: Text(_error!, style: const TextStyle(color: Colors.red))),
      );
    }
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: SimpleCalculator(
          value: _result,
          hideExpression: false,
          onChanged: (key, value, expression) {
            setState(() {
              _result = value ?? 0.0;
            });
            if (value != null) {
              _checkAndNavigate(value);
            }
          },
          theme: const CalculatorThemeData(
            displayColor: Colors.white,
            displayStyle: TextStyle(fontSize: 32, color: Color(0xFF225B84)),
            expressionColor: Colors.white,
            expressionStyle: TextStyle(fontSize: 18, color: Colors.black),
            operatorColor: Color(0xFF225B84),
            operatorStyle: TextStyle(fontSize: 24, color: Colors.white),
            commandColor: Color(0xFFB1C4D7),
            numColor: Color(0xFFEFF3E5),
            numStyle: TextStyle(fontSize: 24, color: Colors.black),
          ),
        ),
      ),
    );
  }
}