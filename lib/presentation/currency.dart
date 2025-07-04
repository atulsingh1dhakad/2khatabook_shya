import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../LIST_LANG.dart';

// --- Color Theme Consistency --- //
const Color kPrimaryBlue = Color(0xFF225B84);
const Color kBackground = Colors.white;
const double kButtonRadius = 8;

class CurrencySettings extends StatefulWidget {
  const CurrencySettings({super.key});

  @override
  State<CurrencySettings> createState() => _CurrencySettingsState();
}

class _CurrencySettingsState extends State<CurrencySettings> {
  final TextEditingController _currencyController = TextEditingController();
  bool _isLoading = false;
  double? _currentSetting;
  String? _errorMsg;

  @override
  void initState() {
    super.initState();
    _fetchCurrencySetting();
    _currencyController.addListener(_onInputChanged);
  }

  @override
  void dispose() {
    _currencyController.dispose();
    super.dispose();
  }

  Future<String?> _getAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString("auth_token");
  }

  Future<void> _fetchCurrencySetting() async {
    setState(() {
      _isLoading = true;
      _errorMsg = null;
    });
    try {
      final authKey = await _getAuthToken();
      if (authKey == null) {
        setState(() {
          _isLoading = false;
          _errorMsg = AppStrings.getString("authTokenMissing");
        });
        return;
      }
      final url = Uri.parse('http://account.galaxyex.xyz/v1/user/api//user/get-login-user');
      final response = await http.get(
        url,
        headers: {
          "Authkey": authKey,
          "Content-Type": "application/json",
        },
      );

      if (response.statusCode == 200) {
        final resp = json.decode(response.body);
        final value = resp['data']?['currencySetting'];
        if (value != null && value.toString().isNotEmpty) {
          setState(() {
            _currentSetting = double.tryParse(value.toString());
            if (_currentSetting != null) {
              _currencyController.text = _currentSetting!.toStringAsFixed(2);
            }
          });
        } else {
          setState(() {
            _currentSetting = null;
            _currencyController.clear();
          });
        }
      } else {
        setState(() {
          _errorMsg = "${AppStrings.getString("serverError")}: ${response.statusCode}";
        });
      }
    } catch (e) {
      setState(() {
        _errorMsg = AppStrings.getString("couldNotFetchCurrentSetting");
      });
    }
    setState(() => _isLoading = false);
  }

  void _onInputChanged() {
    setState(() {
      _errorMsg = null;
    });
  }

  Future<void> _saveCurrencySetting() async {
    setState(() {
      _errorMsg = null;
    });

    final enteredValue = _currencyController.text.trim();
    final parsedValue = double.tryParse(enteredValue);
    if (enteredValue.isEmpty || parsedValue == null || parsedValue <= 0) {
      setState(() {
        _errorMsg = AppStrings.getString("enterValidCurrencyValue");
      });
      return;
    }
    setState(() => _isLoading = true);

    try {
      final authKey = await _getAuthToken();
      if (authKey == null) {
        setState(() {
          _isLoading = false;
          _errorMsg = AppStrings.getString("authTokenMissing");
        });
        return;
      }

      final url = Uri.parse('http://account.galaxyex.xyz/v1/user/api/user/currency-setting');
      final body = {"currencySetting": parsedValue};

      final response = await http.post(
        url,
        headers: {
          "Authkey": authKey,
          "Content-Type": "application/json",
        },
        body: json.encode(body),
      );

      if (response.statusCode == 200) {
        final resp = json.decode(response.body);
        if (resp["meta"]?["status"] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(_currentSetting == null
                ? AppStrings.getString("currencySettingSaved")
                : AppStrings.getString("currencySettingUpdated"))),
          );
          setState(() {
            _currentSetting = parsedValue;
          });
        } else {
          setState(() {
            _errorMsg = resp["meta"]?["msg"] ?? AppStrings.getString("failedToSaveCurrencySetting");
          });
        }
      } else {
        setState(() {
          _errorMsg = '${AppStrings.getString("serverError")}: ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        _errorMsg = "${AppStrings.getString("error")}: $e";
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  bool get _isInputValid {
    final enteredValue = _currencyController.text.trim();
    final parsedValue = double.tryParse(enteredValue);
    return !_isLoading &&
        enteredValue.isNotEmpty &&
        parsedValue != null &&
        parsedValue > 0;
  }

  Widget _buildCurrentSettingCard() {
    if (_currentSetting == null) return const SizedBox(height: 20);
    return Padding(
      padding: const EdgeInsets.only(top: 28.0, left: 25, right: 25, bottom: 6),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: kPrimaryBlue),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${AppStrings.getString("current")}: 1 ₹ = ${_currentSetting!.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 16, color: Colors.black87, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrencyInputRow() {
    return Column(
      children: [
        Row( mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.currency_rupee),
            const Text('1', style: TextStyle(color: Colors.black, fontSize: 25)),
            const SizedBox(width: 20),
            const Text('=', style: TextStyle(color: Colors.black, fontSize: 25)),
            const SizedBox(width: 30),
            SizedBox(
              width: 100,
              child: TextField(
                controller: _currencyController,
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  hintText: AppStrings.getString("currencyValueHint"),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                enabled: !_isLoading,
              ),
            ),
            const SizedBox(width: 20),

          ],
        ),
        const SizedBox(height: 20),
        SizedBox(
          height: 48,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _isInputValid ? kPrimaryBlue : kPrimaryBlue.withOpacity(0.4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(kButtonRadius),
              ),
            ),
            onPressed: _isInputValid ? _saveCurrencySetting : null,
            child: _isLoading
                ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
                : Text(
              _currentSetting == null
                  ? AppStrings.getString("save")
                  : AppStrings.getString("edit"),
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: kPrimaryBlue,
        leading: const BackButton(color: Colors.white),
        title: Text(
          AppStrings.getString("currencySetting"),
          style: const TextStyle(color: Colors.white),
        ),
      ),
      backgroundColor: kBackground,
      body: Column( mainAxisAlignment: MainAxisAlignment.center,
        children: [

          Padding(
            padding: const EdgeInsets.all(25),
            child: Column(
              children: [
                _buildCurrencyInputRow(),
                if (_errorMsg != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 18),
                    child: Text(
                      _errorMsg!,
                      style: const TextStyle(color: Colors.red, fontSize: 15),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}