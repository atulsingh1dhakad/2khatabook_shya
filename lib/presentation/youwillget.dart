import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class YouWillGetPage extends StatefulWidget {
  final String accountId;
  final String accountName;
  final String companyId;

  final String? ledgerId;
  final double? editCredit;
  final String? editRemark;
  final DateTime? editDate;

  const YouWillGetPage({
    super.key,
    required this.accountId,
    required this.accountName,
    required this.companyId,
    this.ledgerId,
    this.editCredit,
    this.editRemark,
    this.editDate,
  });

  @override
  _YouWillGetPageState createState() => _YouWillGetPageState();
}

class _YouWillGetPageState extends State<YouWillGetPage> {
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
        text: widget.editCredit != null ? widget.editCredit!.toString() : "0");
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
    if (isEdit) return; // Prevent date picking in edit mode
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

  String get formattedDate {
    final months = [
      'jan', 'feb', 'mar', 'apr', 'may', 'jun',
      'jul', 'aug', 'sep', 'oct', 'nov', 'dec'
    ];
    return "${_selectedDate.day.toString().padLeft(2, '0')}-"
        "${months[_selectedDate.month - 1]}-"
        "${_selectedDate.year}";
  }

  String get isoDate =>
      "${_selectedDate.year.toString().padLeft(4, '0')}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}";

  Future<void> _saveData() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
    });

    final prefs = await SharedPreferences.getInstance();
    final authKey = prefs.getString("auth_token");
    final amount = double.tryParse(_amountController.text.replaceAll(',', '')) ?? 0;

    final body = {
      "amount": amount,
      "remark": _remarkController.text,
      "entryType": "get",
      "companyId": widget.companyId,
      "accountId": widget.accountId,
      "date": isoDate,
      if (isEdit) "ledgerId": widget.ledgerId,
    };

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
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e")));
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _onAttachFile() {
    // TODO: Implement file/camera picker logic
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Attach file/camera not implemented")),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Both widgets width = half - spacing, height = 40
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        leading: const BackButton(color: Colors.white,),
        title: Text(
            isEdit ? 'Edit Entry (You Will Get)' : 'You Will Get From ${widget.accountName}',
            style: const TextStyle(fontSize: 15, color: Colors.white)),
        backgroundColor: const Color(0xFF5D8D4B),
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
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 40,
                      child: IgnorePointer(
                        ignoring: isEdit, // Prevent editing date on update
                        child: InkWell(
                          onTap: _pickDate,
                          child: InputDecorator(
                            decoration: InputDecoration(
                              border: const OutlineInputBorder(),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              enabled: !isEdit,
                              fillColor: isEdit ? Colors.grey.shade100 : null,
                              filled: isEdit,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    formattedDate,
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                ),
                                const Icon(Icons.calendar_today, size: 16),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SizedBox(
                      height: 40,
                      child: OutlinedButton.icon(
                        onPressed: _onAttachFile,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          side: const BorderSide(),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(7),
                          ),
                        ),
                        icon: const Icon(Icons.camera_alt, size: 18, color: Colors.black,),
                        label: const Text("Attach File", style: TextStyle(fontSize: 13,color: Colors.grey)),
                      ),
                    ),
                  ),
                ],
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
              backgroundColor: const Color(0xFF5D8D4B),
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