import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http_interceptor/http_interceptor.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'LIST_LANG.dart';
import 'auth_interceptor.dart';
import 'presentation/loginscreen.dart';
import 'security/calciscreen.dart';
import 'presentation/homescreen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final RouteObserver<ModalRoute<void>> routeObserver = RouteObserver<ModalRoute<void>>();

final http.Client httpClient = InterceptedClient.build(
  interceptors: [AuthInterceptor(navigatorKey)],
);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize language for AppStrings before building any widget.
  final prefs = await SharedPreferences.getInstance();
  final langCode = prefs.getString('selected_language_code') ?? 'en';
  AppStrings.setLanguage(langCode);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      navigatorObservers: [routeObserver],
      debugShowCheckedModeBanner: false,
      home: const EntryGate(),
    );
  }
}

class EntryGate extends StatefulWidget {
  const EntryGate({super.key});

  @override
  State<EntryGate> createState() => _EntryGateState();
}

class _EntryGateState extends State<EntryGate> {
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _decideNavigation();
  }

  Future<void> _decideNavigation() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    bool isFirstOpen = prefs.getBool('is_first_open') ?? true;

    if (isFirstOpen) {
      await prefs.setBool('is_first_open', false);
      _pushReplace(const EmailLoginScreen());
      return;
    }

    String? token = prefs.getString('auth_token');
    if (token != null && token.isNotEmpty) {
      int? expiryTimestamp = prefs.getInt('token_expiry');
      if (expiryTimestamp != null) {
        final now = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
        if (now >= expiryTimestamp) {
          await prefs.remove('auth_token');
          await prefs.remove('token_expiry');
          _pushReplace(const EmailLoginScreen());
          return;
        }
      }

      bool? isSecurityActive = await _checkSecurityActive(token);

      // If API call fails, treat as security OFF (let user in normally).
      if (isSecurityActive == true) {
        _pushReplace(const CustomCalculatorScreen());
      } else {
        // security is OFF or error: go to homescreen directly
        _pushReplace(const HomeScreen());
      }
    } else {
      _pushReplace(const EmailLoginScreen());
    }
  }

  /// Returns:
  ///   - true  : if security is active
  ///   - false : if security is not active
  ///   - null  : if network/server error or unexpected response
  Future<bool?> _checkSecurityActive(String token) async {
    try {
      final url = Uri.parse("http://account.galaxyex.xyz/v1/user/api/setting/get-security");
      final res = await httpClient.get(url);

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data["meta"]?["status"] == true && data["data"] != null) {
          return data["data"]["isActive"] == true;
        }
      }
      // Any non-200 or unexpected response is an error (treat as security OFF)
      return false;
    } catch (e) {
      // Any network/server error is treated as security OFF
      return false;
    }
  }

  void _pushReplace(Widget screen) {
    if (_navigated) return;
    _navigated = true;
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