import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class AddCustomerPage extends StatefulWidget {
  final String companyId;

  const AddCustomerPage({super.key, required this.companyId});

  @override
  _AddCustomerPageState createState() => _AddCustomerPageState();
}

class _AddCustomerPageState extends State<AddCustomerPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _remarkController = TextEditingController();
  bool _isLoading = false;

  Future<void> _createCustomer() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _isLoading = true; });

    final prefs = await SharedPreferences.getInstance();
    final authKey = prefs.getString("auth_token");

    final url = Uri.parse('http://account.galaxyex.xyz/v1/user/api/account/add-account');
    final body = {
      'customerName': _nameController.text,
      'companyId': widget.companyId,
      'remark': _remarkController.text,
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
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Customer created successfully!')),
        );
        Navigator.pop(context, true);
      } else {
        String msg = "Failed to create customer";
        try {
          final respJson = json.decode(response.body);
          if (respJson['meta'] != null && respJson['meta']['msg'] != null) {
            msg = respJson['meta']['msg'];
          }
        } catch (_) {}
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() { _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        leading: BackButton(color: Colors.white,),
        title: Text('Add Customer',style: TextStyle(color: Colors.white),),
        backgroundColor: Color(0xFF23608A),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(10),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  hintText: 'Customer Name',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                ),
                validator: (value) =>
                value == null || value.trim().isEmpty ? 'Enter customer name' : null,
              ),
              SizedBox(height: 10),
              Container(
                height: 100,
                child: TextFormField(
                  controller: _remarkController,
                  decoration: InputDecoration(
                    hintText: 'Remark',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  ),
                  textAlignVertical: TextAlignVertical.top,
                  maxLines: null,
                  expands: true,
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
          child: ElevatedButton.icon(
            onPressed: _isLoading ? null : _createCustomer,
            icon: Icon(Icons.person_add, color: Colors.white),
            label: Text('Create Customer',style: TextStyle(color: Colors.white),),
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF23608A),
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