import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class YouWillGivePage extends StatefulWidget {
  final String accountId;
  final String accountName;
  final String companyId;

  const YouWillGivePage({
    super.key,
    required this.accountId,
    required this.accountName,
    required this.companyId,
  });

  @override
  _YouWillGivePageState createState() => _YouWillGivePageState();
}

class _YouWillGivePageState extends State<YouWillGivePage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _amountController = TextEditingController(text: "0");
  final TextEditingController _remarkController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;

  Future<void> _pickDate() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  String get formattedDate =>
      "${_selectedDate.day.toString().padLeft(2, '0')}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.year}";

  String get isoDate =>
      "${_selectedDate.year.toString().padLeft(4, '0')}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}";

  Future<void> _saveData() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
    });

    final prefs = await SharedPreferences.getInstance();
    final authKey = prefs.getString("auth_token");

    final url = Uri.parse('http://account.galaxyex.xyz/v1/user/api/account/add-ledger');
    final amount = double.tryParse(_amountController.text.replaceAll(',', '')) ?? 0;

    final body = {
      "amount": amount,
      "remark": _remarkController.text,
      "entryType": "give",
      "companyId": widget.companyId,
      "accountId": widget.accountId,
      "date": isoDate,
    };

    try {
      final response = await http.post(
        url,
        headers: {
          "Content-Type": "application/json",
          "Authkey": authKey ?? "",
        },
        body: json.encode(body),
      );
      print("Status: ${response.statusCode}");
      print("Body: ${response.body}");

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonResp = json.decode(response.body);
        if (jsonResp['meta'] != null && jsonResp['meta']['status'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Saved successfully!")));
          Navigator.pop(context, true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(jsonResp['meta']?['msg'] ?? "Failed to save (API error)")));
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Failed to save (${response.statusCode})")));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e")));
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        leading: const BackButton(color: Colors.white,),
        title: Text('You Will Give To ${widget.accountName}', style: const TextStyle(fontSize: 15, color: Colors.white)),
        backgroundColor: const Color(0xffc96868),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(10),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                ),
                validator: (value) =>
                value == null || value.trim().isEmpty || double.tryParse(value.replaceAll(',', '')) == null
                    ? 'Enter a valid amount'
                    : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _remarkController,
                decoration: const InputDecoration(
                  hintText: 'Remark',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                ),
              ),
              const SizedBox(height: 10),
              InkWell(
                onTap: _pickDate,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  ),
                  child: Row(
                    children: [
                      Expanded(child: Text(formattedDate)),
                      const Icon(Icons.calendar_today, size: 18),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
      bottomNavigationBar: AnimatedPadding(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: EdgeInsets.only(
          left: 8,
          right: 8,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _saveData,
            child: _isLoading
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text('Save', style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xffc96868),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(7),
              ),
            ),
          ),
        ),
      ),
    );
  }
}