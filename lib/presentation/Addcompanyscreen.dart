import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../LIST_LANG.dart';

class AddCompanyPage extends StatefulWidget {
  final String? companyId;
  final String? initialName;

  // Accepts companyId and initialName for editing
  const AddCompanyPage({Key? key, this.companyId, this.initialName}) : super(key: key);

  @override
  _AddCompanyPageState createState() => _AddCompanyPageState();
}

class _AddCompanyPageState extends State<AddCompanyPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  bool _isLoading = false;

  bool get isEdit => widget.companyId != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName ?? "");
  }

  Future<void> _submitCompany() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
    });

    final prefs = await SharedPreferences.getInstance();
    final authKey = prefs.getString("auth_token");

    final url = Uri.parse('http://account.galaxyex.xyz/v1/user/api/account/add-company');

    final body = isEdit
        ? {
      'companyId': widget.companyId,
      'companyName': _nameController.text.trim(),
    }
        : {
      'companyName': _nameController.text.trim(),
    };

    try {
      final response = await http.post(
        url,
        headers: {
          "Content-Type": "application/json",
          if (authKey != null) "Authkey": authKey,
        },
        body: json.encode(body),
      );
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isEdit
              ? AppStrings.getString("companyUpdatedSuccessfully")
              : AppStrings.getString("companyCreatedSuccessfully"))),
        );
        Navigator.pop(context, true);
      } else {
        String msg = isEdit
            ? AppStrings.getString("failedToUpdateCompany")
            : AppStrings.getString("failedToCreateCompany");
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
        SnackBar(content: Text('${AppStrings.getString("error")}: $e')),
      );
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
        leading: const BackButton(
          color: Colors.white,
        ),
        title: Text(
          isEdit
              ? AppStrings.getString("editCompany")
              : AppStrings.getString("addCompany"),
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF23608A),
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
                  hintText: AppStrings.getString("companyName"),
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? AppStrings.getString("enterCompanyName")
                    : null,
              ),
              const SizedBox(height: 10),
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
            onPressed: _isLoading ? null : _submitCompany,
            icon: Icon(isEdit ? Icons.edit : Icons.add, color: Colors.white),
            label: Text(
              isEdit
                  ? AppStrings.getString("updateCompany")
                  : AppStrings.getString("addCompany"),
              style: const TextStyle(color: Colors.white),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF23608A),
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