import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class AddCustomerPage extends StatefulWidget {
  final String companyId;
  final String? initialName;
  final String? initialRemark;
  final String? accountId;
  final bool isEdit;

  const AddCustomerPage({
    super.key,
    required this.companyId,
    this.initialName,
    this.initialRemark,
    this.accountId,
    this.isEdit = false,
  });

  @override
  _AddCustomerPageState createState() => _AddCustomerPageState();
}

class _AddCustomerPageState extends State<AddCustomerPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _remarkController;
  bool _isLoading = false;

  // Staff related state
  bool _isStaffLoading = true;
  String? _staffError;
  List<dynamic> _staffList = [];
  Map<int, bool> _staffVisibility = {}; // staff index to visibility state
  String _staffSearchQuery = "";
  final TextEditingController _staffSearchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName ?? "");
    _remarkController = TextEditingController(text: widget.initialRemark ?? "");
    _fetchStaffList();
    _staffSearchController.addListener(() {
      setState(() {
        _staffSearchQuery = _staffSearchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _remarkController.dispose();
    _staffSearchController.dispose();
    super.dispose();
  }

  Future<String?> _getAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString("auth_token");
  }

  Future<void> _fetchStaffList() async {
    setState(() {
      _isStaffLoading = true;
      _staffError = null;
      _staffList = [];
    });

    final authKey = await _getAuthToken();
    if (authKey == null) {
      setState(() {
        _staffError = "Authentication token missing. Please log in.";
        _isStaffLoading = false;
      });
      return;
    }

    final url = "http://account.galaxyex.xyz/v1/user/api/user/get-staff";
    try {
      final response = await http.get(Uri.parse(url), headers: {
        "Authkey": authKey,
        "Content-Type": "application/json",
      });

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = json.decode(response.body);
        if (jsonData['meta'] != null && jsonData['meta']['status'] == true) {
          final data = jsonData['data'] ?? [];
          setState(() {
            _staffList = data;
            // Set all staff to show by default (true)
            _staffVisibility = {
              for (int i = 0; i < data.length; i++) i: true
            };
            _isStaffLoading = false;
          });
        } else {
          setState(() {
            _staffError = jsonData['meta']?['msg'] ?? "Failed to fetch staff list";
            _isStaffLoading = false;
          });
        }
      } else {
        setState(() {
          _staffError = "Server error: ${response.statusCode}";
          _isStaffLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _staffError = "Error: $e";
        _isStaffLoading = false;
      });
    }
  }

  Future<void> _submitCustomer() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
    });

    final prefs = await SharedPreferences.getInstance();
    final authKey = prefs.getString("auth_token");

    final isEdit = widget.isEdit;
    final url = Uri.parse('http://account.galaxyex.xyz/v1/user/api/account/add-account');
    final body = isEdit
        ? {
      'customerName': _nameController.text,
      'companyId': widget.companyId,
      'remark': _remarkController.text,
      'accountId': widget.accountId,
    }
        : {
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
          SnackBar(content: Text(isEdit ? 'Customer updated successfully!' : 'Customer created successfully!')),
        );
        Navigator.pop(context, true);
      } else {
        String msg = isEdit ? "Failed to update customer" : "Failed to create customer";
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
      setState(() {
        _isLoading = false;
      });
    }
  }

  Widget _buildStaffListSection() {
    if (_isStaffLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 18),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_staffError != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Center(child: Text(_staffError!, style: const TextStyle(color: Colors.red))),
      );
    }
    if (_staffList.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 14),
        child: Center(child: Text("No staff available.")),
      );
    }
    // Filter staff by search query
    final filteredStaff = _staffSearchQuery.isEmpty
        ? _staffList
        : _staffList.where((staff) {
      final name = (staff['name'] ?? "").toString().toLowerCase();
      final loginId = (staff['loginId'] ?? "").toString().toLowerCase();
      return name.contains(_staffSearchQuery) || loginId.contains(_staffSearchQuery);
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 16.0, bottom: 4, left: 2),
          child: Text(
            "Staff List",
            style: TextStyle(
              color: Color(0xFF23608A),
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 10, top: 2),
          child: TextField(
            controller: _staffSearchController,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: "Search Staff",
              contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              isDense: true,
            ),
          ),
        ),
        filteredStaff.isEmpty
            ? const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Center(child: Text("No staff found.")),
        )
            : Column(
          children: List.generate(filteredStaff.length, (filteredIndex) {
            // Find the index in the original list to get correct toggle state
            final staff = filteredStaff[filteredIndex];
            final index = _staffList.indexOf(staff);
            final name = staff['name'] ?? "N/A";
            final loginId = staff['loginId'] ?? "N/A";
            final show = _staffVisibility[index] ?? true;
            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
              decoration: BoxDecoration(
                color: show ? const Color(0xFFE3F2FD) : const Color(0xFFFFEBEE),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: TextStyle(
                            color: show ? const Color(0xFF23608A) : Colors.red[700],
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "UserID: $loginId",
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Toggle switch
                  Row(
                    children: [
                      Text(
                        show ? "Show" : "Hide",
                        style: TextStyle(
                          color: show ? Colors.blue[800] : Colors.red[700],
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Switch(
                        value: show,
                        activeColor: const Color(0xFF23608A),
                        inactiveThumbColor: Colors.red,
                        inactiveTrackColor: Colors.red[200],
                        onChanged: (val) {
                          setState(() {
                            _staffVisibility[index] = val;
                          });
                        },
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.isEdit;
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        leading: const BackButton(color: Colors.white),
        title: Text(isEdit ? 'Edit Customer' : 'Add Customer', style: const TextStyle(color: Colors.white)),
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
                decoration: const InputDecoration(
                  hintText: 'Customer Name',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                ),
                validator: (value) =>
                value == null || value.trim().isEmpty ? 'Enter customer name' : null,
              ),
              const SizedBox(height: 10),
              Container(
                height: 100,
                child: TextFormField(
                  controller: _remarkController,
                  decoration: const InputDecoration(
                    hintText: 'Remark',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  ),
                  textAlignVertical: TextAlignVertical.top,
                  maxLines: null,
                  expands: true,
                ),
              ),
              _buildStaffListSection(),
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
            onPressed: _isLoading ? null : _submitCustomer,
            icon: Icon(isEdit ? Icons.save : Icons.person_add, color: Colors.white),
            label: Text(isEdit ? 'Update Customer' : 'Create Customer', style: const TextStyle(color: Colors.white)),
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