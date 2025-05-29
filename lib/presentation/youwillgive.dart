import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class YouWillGivePage extends StatefulWidget {
  final String accountId;
  final String accountName;
  final String companyId;

  // Edit mode params
  final String? ledgerId;
  final double? editDebit;
  final String? editRemark;
  final DateTime? editDate;

  const YouWillGivePage({
    Key? key,
    required this.accountId,
    required this.accountName,
    required this.companyId,
    this.ledgerId,
    this.editDebit,
    this.editRemark,
    this.editDate,
  }) : super(key: key);

  @override
  _YouWillGivePageState createState() => _YouWillGivePageState();
}

class _YouWillGivePageState extends State<YouWillGivePage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _amountController;
  late TextEditingController _remarkController;
  late DateTime _selectedDate;
  bool _isLoading = false;

  bool get isEdit => widget.ledgerId != null;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
        text: widget.editDebit != null ? widget.editDebit!.toStringAsFixed(0) : "0");
    _remarkController =
        TextEditingController(text: widget.editRemark ?? "");
    _selectedDate = widget.editDate ?? DateTime.now();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _remarkController.dispose();
    super.dispose();
  }

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

  String get isoDate =>
      "${_selectedDate.year.toString().padLeft(4, '0')}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}";

  Future<void> _saveData() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final prefs = await SharedPreferences.getInstance();
    final authKey = prefs.getString("auth_token");
    final amount = double.tryParse(_amountController.text.trim()) ?? 0;

    // Match Postman JSON exactly!
    final Map<String, dynamic> body = {
      if (isEdit) "ledgerId": widget.ledgerId,
      "amount": amount,
      "remark": _remarkController.text.trim(),
      "entryType": "give",
      "companyId": widget.companyId,
      "accountId": widget.accountId,
      "date": isoDate,
    };

    print("Submitting body: $body");

    final url = Uri.parse('http://account.galaxyex.xyz/v1/user/api/account/add-ledger');

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
              SnackBar(content: Text(isEdit ? "Updated successfully!" : "Saved successfully!")));
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        leading: const BackButton(color: Colors.white,),
        title: Text(
            isEdit ? 'Edit Entry (You Will Give)' : 'You Will Give To ${widget.accountName}',
            style: const TextStyle(fontSize: 15, color: Colors.white)),
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
                value == null ||
                    value.trim().isEmpty ||
                    double.tryParse(value.trim()) == null
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
                      Expanded(child: Text(
                          "${_selectedDate.day.toString().padLeft(2, '0')}-"
                              "${_selectedDate.month.toString().padLeft(2, '0')}-"
                              "${_selectedDate.year}")),
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
                : Text(isEdit ? 'Update' : 'Save', style: const TextStyle(color: Colors.white)),
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