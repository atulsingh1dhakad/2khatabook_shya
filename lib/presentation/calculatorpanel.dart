import 'package:flutter/material.dart';
import 'package:math_expressions/math_expressions.dart';

class CalculatorPanel extends StatefulWidget {
  final String initialInput;
  final Color accentColor;
  final void Function(String rawInput, String preview, double? value) onChanged;
  final VoidCallback onDone;
  const CalculatorPanel({
    Key? key,
    required this.initialInput,
    required this.accentColor,
    required this.onChanged,
    required this.onDone,
  }) : super(key: key);

  @override
  State<CalculatorPanel> createState() => _CalculatorPanelState();
}

class _CalculatorPanelState extends State<CalculatorPanel> {
  late String _input;
  String _preview = "";
  double? _result;
  bool _justEvaluated = false;

  @override
  void initState() {
    super.initState();
    _input = widget.initialInput;
    _calculatePreview(notify: false);
  }

  void _calculatePreview({bool notify = true}) {
    final hasOperator = RegExp(r'[+\-*/×÷]').hasMatch(_input);
    final endsWithOperator = RegExp(r'[+\-*/×÷%]$').hasMatch(_input);

    try {
      if (_input.isEmpty) {
        _preview = "";
        _result = null;
        if (notify && mounted) widget.onChanged(_input, _preview, _result);
        return;
      }

      String preparedInput = _handlePercent(_input);
      Parser p = Parser();
      Expression exp = p.parse(preparedInput.replaceAll('×', '*').replaceAll('÷', '/'));
      double eval = exp.evaluate(EvaluationType.REAL, ContextModel());

      if (hasOperator || endsWithOperator) {
        _preview = "$_input = $eval";
      } else {
        _preview = "";
      }

      _result = eval;
      if (notify && mounted) widget.onChanged(_input, _preview, _result);
    } catch (_) {
      if (notify && mounted) widget.onChanged(_input, "", null);
      _preview = "";
      _result = null;
    }
  }

  String _handlePercent(String input) {
    return input.replaceAllMapped(
      RegExp(r'(\d+(\.\d+)?)%'),
          (match) => '(${match.group(1)}/100)',
    );
  }

  void _onPressed(String text) {
    setState(() {
      if (text == "C") {
        _input = "";
        _justEvaluated = false;
        _calculatePreview();
      } else if (text == "⌫") {
        if (_input.isNotEmpty) _input = _input.substring(0, _input.length - 1);
        _calculatePreview();
      } else if (text == "=") {
        _calculatePreview();
        if (_result != null) {
          String resultStr = _result!.toStringAsFixed(_result! % 1 == 0 ? 0 : 2);
          _input = resultStr;
          _preview = "";
          _result = double.tryParse(resultStr);
          _justEvaluated = true;
          if (mounted) widget.onChanged(_input, "", _result);
        }
      } else if (text == "✔") {
        widget.onDone();
      } else {
        if (_justEvaluated) {
          if (RegExp(r'[0-9.]').hasMatch(text)) {
            _input = text;
          } else if (RegExp(r'[+\-×÷*/%]').hasMatch(text)) {
            _input += text;
          }
          _justEvaluated = false;
        } else {
          _input += text;
        }
        _calculatePreview();
      }
    });
  }

  Widget _buildButton(String text, {Color? color, double fontSize = 20, VoidCallback? onTap, bool expanded = true}) {
    final button = Padding(
      padding: const EdgeInsets.all(2.0),
      child: ElevatedButton(
        onPressed: onTap ?? () => _onPressed(text),
        style: ElevatedButton.styleFrom(
          foregroundColor: Colors.black87,
          backgroundColor: color ?? Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          elevation: 0,
          shadowColor: Colors.transparent,
        ),
        child: text == "✔"
            ? Icon(Icons.check, color: widget.accentColor, size: fontSize + 2)
            : Text(text, style: TextStyle(fontSize: fontSize)),
      ),
    );
    return expanded ? Expanded(child: button) : button;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Removed the preview from here!
          Row(
            children: [
              _buildButton("C", color: Colors.blue[50]!),
              _buildButton("%", color: Colors.blue[50]!),
              _buildButton("⌫", color: Colors.blue[50]!, fontSize: 22),
              _buildButton("÷", color: Colors.blue[50]!),
            ],
          ),
          Row(
            children: [
              _buildButton("7", color: Colors.grey[100]!),
              _buildButton("8", color: Colors.grey[100]!),
              _buildButton("9", color: Colors.grey[100]!),
              _buildButton("×", color: Colors.blue[50]!),
            ],
          ),
          Row(
            children: [
              _buildButton("4", color: Colors.grey[100]!),
              _buildButton("5", color: Colors.grey[100]!),
              _buildButton("6", color: Colors.grey[100]!),
              _buildButton("-", color: Colors.blue[50]!),
            ],
          ),
          Row(
            children: [
              _buildButton("1", color: Colors.grey[100]!),
              _buildButton("2", color: Colors.grey[100]!),
              _buildButton("3", color: Colors.grey[100]!),
              _buildButton("+", color: Colors.blue[50]!),
            ],
          ),
          Row(
            children: [
              _buildButton("0", color: Colors.grey[100]!),
              _buildButton(".", color: Colors.grey[100]!),
              SizedBox(
                width: 85,
                child: _buildButton(
                  "=",
                  color: widget.accentColor.withOpacity(0.30),
                  fontSize: 22,
                  expanded: false,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}