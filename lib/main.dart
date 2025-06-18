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
  // Do NOT set language here. Only set after user login or after first open if user selects.
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  // We do NOT set _locale here; language will be set after login or on first open.

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
    _startNavigation();
  }

  void _startNavigation() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _decideNavigation();
    });
  }

  Future<void> _decideNavigation() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();

      // Always clear everything if is_first_open is not set or true
      bool isFirstOpen = prefs.getBool('is_first_open') ?? true;

      if (isFirstOpen) {
        await prefs.clear();
        await prefs.setBool('is_first_open', false);

        // DO NOT set language here on first open
        // Optionally: Show a language picker screen here, or just go to login

        _pushReplace(const EmailLoginScreen());
        return;
      }

      String? token = prefs.getString('auth_token');
      if (token == null || token.trim().isEmpty) {
        _pushReplace(const EmailLoginScreen());
        return;
      }

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

      // Only set language if the user has logged in before (not on first open)
      String langCode = prefs.getString('app_language') ?? 'en';
      await AppStrings.setLanguage(langCode);

      bool? isSecurityActive = await _checkSecurityActive(token);

      if (isSecurityActive == true) {
        _pushReplace(const CustomCalculatorScreen());
      } else {
        _pushReplace(const HomeScreen());
      }
    } catch (e, st) {
      print("Exception in _decideNavigation: $e\n$st");
      // Do NOT set language here on first open
      _pushReplace(const EmailLoginScreen());
    }
  }

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
      return false;
    } catch (e) {
      return false;
    }
  }

  void _pushReplace(Widget screen) {
    if (_navigated) return;
    _navigated = true;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}