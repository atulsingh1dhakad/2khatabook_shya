import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:math_expressions/math_expressions.dart';

import '../presentation/homescreen.dart';

// Custom calculator button colors
const Color kBgColor = Colors.black;
const Color kButtonCircle = Color(0xFF18120C);
const Color kButtonCircleAlt = Color(0xFF39322D);
const Color kButtonGold = Color(0xFFEFB609);
const Color kGoldText = Color(0xFFFFFFFF);
const Color kRedText = Color(0xFFD26868);
const Color kWhite = Colors.white;

class CustomCalculatorScreen extends StatefulWidget {
  const CustomCalculatorScreen({Key? key}) : super(key: key);

  @override
  State<CustomCalculatorScreen> createState() => _CustomCalculatorScreenState();
}

class _CustomCalculatorScreenState extends State<CustomCalculatorScreen> {
  String _expression = '';
  String _result = '';
  bool _shouldClear = false;

  int? _securityPin;

  @override
  void initState() {
    super.initState();
    _fetchSecurityPin();
  }

  Future<void> _fetchSecurityPin() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('auth_token');

      if (token == null || token.isEmpty) {
        return;
      }

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
            _securityPin = data["data"]["code"];
          });
        }
      }
    } catch (e) {
      // Optionally handle error
    }
  }

  void _onButtonPressed(String value) {
    setState(() {
      if (value == 'C') {
        _expression = '';
        _result = '';
        _shouldClear = false;
      } else if (value == '=') {
        try {
          _result = _calculateResult(_expression);
          _shouldClear = true;
          _checkAndNavigate(_result);
        } catch (e) {
          _result = 'Err';
        }
      } else if (value == '+/-') {
        // Toggle sign of the last number
        final regex = RegExp(r'([0-9.]+)$');
        final match = regex.firstMatch(_expression);
        if (match != null) {
          final lastNumber = match.group(1)!;
          if (_expression.endsWith(lastNumber)) {
            if (lastNumber.startsWith('-')) {
              _expression =
                  _expression.substring(0, _expression.length - lastNumber.length) +
                      lastNumber.substring(1);
            } else {
              _expression =
                  _expression.substring(0, _expression.length - lastNumber.length) +
                      '-' +
                      lastNumber;
            }
          }
        }
      } else {
        if (_shouldClear) {
          _expression = '';
          _shouldClear = false;
        }
        _expression += value;
      }
    });
  }

  void _checkAndNavigate(String result) {
    if (_securityPin == null) return;
    double? resultNum = double.tryParse(result);
    if (resultNum != null && resultNum.toInt() == _securityPin) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    }
  }

  // --- PERCENT FIX START ---
  String _handlePercent(String input) {
    String out = input;
    // Replace e.g. 100-25% with 100-(100*25/100)
    out = out.replaceAllMapped(
      RegExp(r'(\d+(\.\d+)?)([+\-*/])(\d+(\.\d+)?)%'),
          (match) {
        final first = match.group(1)!;
        final op = match.group(3)!;
        final percent = match.group(4)!;
        return '$first$op($first*$percent/100)';
      },
    );
    // Replace a standalone percent at the end
    out = out.replaceAllMapped(
      RegExp(r'^(\d+(\.\d+)?)%$'),
          (match) => '(${match.group(1)})/100',
    );
    // Also handle if just last number is a percent, e.g. 25+5%
    out = out.replaceAllMapped(
      RegExp(r'([+\-*/])(\d+(\.\d+)?)%'),
          (match) {
        final op = match.group(1)!;
        // find the value before the op
        final prevMatch =
        RegExp(r'(\d+(\.\d+)?)(?=[+\-*/][^+\-*/]*$)').firstMatch(out);
        final base = prevMatch != null ? prevMatch.group(1)! : "0";
        final percent = match.group(2)!;
        return '$op($base*$percent/100)';
      },
    );
    return out;
  }
  // --- PERCENT FIX END ---

  String _calculateResult(String exp) {
    try {
      exp = exp.replaceAll('×', '*').replaceAll('÷', '/');
      exp = _handlePercent(exp);
      Parser p = Parser();
      Expression expression = p.parse(exp);
      ContextModel cm = ContextModel();
      double eval = expression.evaluate(EvaluationType.REAL, cm);
      return eval.toString();
    } catch (e) {
      return 'Err';
    }
  }

  Widget _buildButton({
    required String label,
    Color? bgColor,
    Color? fgColor,
    double fontSize = 24,
    FontWeight fontWeight = FontWeight.bold,
  }) {
    return SizedBox(
      width: 66,
      height: 66,
      child: RawMaterialButton(
        onPressed: () => _onButtonPressed(label),
        elevation: 0,
        fillColor: bgColor ?? kButtonCircle,
        shape: const CircleBorder(),
        child: Text(
          label,
          style: TextStyle(
            color: fgColor ?? kGoldText,
            fontSize: fontSize,
            fontWeight: fontWeight,
          ),
        ),
      ),
    );
  }

  Widget _buildCalculator() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        // Display
        Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20, top: 40, bottom: 8),
          height: 120,
          child: Text(
            _result.isNotEmpty ? _result : _expression,
            style: const TextStyle(
              color: kGoldText,
              fontSize: 36,
              fontWeight: FontWeight.w400,
              letterSpacing: 2.0,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        // Row: utility icons (optional, non-functional here)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22.0, vertical: 7),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(Icons.timer, color: kGoldText.withOpacity(0.5), size: 22),
              Icon(Icons.battery_3_bar, color: kGoldText.withOpacity(0.5), size: 22),
              Icon(Icons.grid_3x3, color: kGoldText.withOpacity(0.5), size: 22),
              Icon(Icons.close, color: kGoldText.withOpacity(0.5), size: 22),
            ],
          ),
        ),
        const SizedBox(height: 9),
        // Buttons
        _buildButtonRow(['C', '()', '%', '÷'],
            circleColors: [kButtonCircleAlt, kButtonCircleAlt, kButtonCircleAlt, kButtonCircleAlt],
            textColors: [kRedText, kGoldText, kGoldText, kGoldText]),
        _buildButtonRow(['7', '8', '9', '×']),
        _buildButtonRow(['4', '5', '6', '-']),
        _buildButtonRow(['1', '2', '3', '+']),
        _buildButtonRow(['+/-', '0', '.', '='],
            circleColors: [kButtonCircleAlt, kButtonCircle, kButtonCircle, kButtonGold],
            textColors: [kGoldText, kGoldText, kGoldText, kWhite]),
        const SizedBox(height: 22),
      ],
    );
  }

  Widget _buildButtonRow(List<String> labels,
      {List<Color>? circleColors, List<Color>? textColors}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5.2, horizontal: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(labels.length, (i) {
          return _buildButton(
            label: labels[i],
            bgColor: circleColors != null && i < circleColors.length
                ? circleColors[i]
                : kButtonCircle,
            fgColor: textColors != null && i < textColors.length
                ? textColors[i]
                : kGoldText,
            fontSize: labels[i] == '=' ? 30 : 24,
            fontWeight: labels[i] == '=' ? FontWeight.bold : FontWeight.bold,
          );
        }),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBgColor,
      body: SafeArea(
        child: _buildCalculator(),
      ),
    );
  }
}