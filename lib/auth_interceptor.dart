import 'package:flutter/material.dart';
import 'package:http_interceptor/http_interceptor.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'presentation/loginscreen.dart';

class AuthInterceptor implements InterceptorContract {
  final GlobalKey<NavigatorState> navigatorKey;

  AuthInterceptor(this.navigatorKey);

  @override
  Future<bool> shouldInterceptRequest() async => true;

  @override
  Future<bool> shouldInterceptResponse() async => true;

  @override
  Future<BaseRequest> interceptRequest({required BaseRequest request}) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('auth_token');
    if (token != null && token.isNotEmpty) {
      request.headers['Authkey'] = token;
      request.headers['Content-Type'] = 'application/json';
    }
    return request;
  }

  @override
  Future<BaseResponse> interceptResponse({required BaseResponse response}) async {
    if (response.statusCode == 401 || response.statusCode == 403) {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.remove('auth_token');
      await prefs.remove('token_expiry');
      navigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const EmailLoginScreen()),
            (route) => false,
      );
    }
    return response;
  }
}