import 'package:flutter/material.dart';
import 'package:flutter_simple_calculator/flutter_simple_calculator.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Simple Calculator',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const SimpleCalculatorScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class SimpleCalculatorScreen extends StatefulWidget {
  const SimpleCalculatorScreen({Key? key}) : super(key: key);

  @override
  State<SimpleCalculatorScreen> createState() => _SimpleCalculatorScreenState();
}

class _SimpleCalculatorScreenState extends State<SimpleCalculatorScreen> {
  double _result = 0.0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      /*appBar: AppBar(
        title: const Text("Simple Calculator"),
        backgroundColor: const Color(0xFF225B84),
      ),*/
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: SimpleCalculator(
          value: _result,
          hideExpression: false,
          onChanged: (key, value, expression) {
            setState(() {
              _result = value ?? 0.0;
            });
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