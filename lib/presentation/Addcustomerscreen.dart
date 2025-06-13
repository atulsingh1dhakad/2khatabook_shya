import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../LIST_LANG.dart';

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

  bool _isStaffLoading = true;
  String? _staffError;
  List<dynamic> _staffList = [];
  Map<int, bool> _staffVisibility = {};
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

    if (widget.companyId.isEmpty) {
      setState(() {
        _isStaffLoading = false;
        _staffList = [];
        _staffVisibility = {};
      });
      return;
    }

    final authKey = await _getAuthToken();
    if (authKey == null) {
      setState(() {
        _staffError = AppStrings.getString("authTokenMissing");
        _isStaffLoading = false;
      });
      return;
    }

    final staffUrl = "http://account.galaxyex.xyz/v1/user/api/user/get-staff";
    List<dynamic> staffData = [];
    try {
      final staffResponse = await http.get(Uri.parse(staffUrl), headers: {
        "Authkey": authKey,
        "Content-Type": "application/json",
      });

      if (staffResponse.statusCode == 200) {
        final Map<String, dynamic> staffJson = json.decode(staffResponse.body);
        if (staffJson['meta'] != null && staffJson['meta']['status'] == true) {
          staffData = staffJson['data'] ?? [];
        } else {
          setState(() {
            _staffError = staffJson['meta']?['msg'] ?? AppStrings.getString("failedToFetchStaff");
            _isStaffLoading = false;
          });
          return;
        }
      } else {
        setState(() {
          _staffError = "${AppStrings.getString("serverError")}: ${staffResponse.statusCode}";
          _isStaffLoading = false;
        });
        return;
      }
    } catch (e) {
      setState(() {
        _staffError = "${AppStrings.getString("error")}: $e";
        _isStaffLoading = false;
      });
      return;
    }

    final filteredStaff = staffData.where((staff) {
      final accessList = staff['companyAccess'] as List<dynamic>? ?? [];
      return accessList.any((access) {
        final action = (access['action']?.toString() ?? '').toUpperCase();
        return access['companyId'] == widget.companyId &&
            (action == 'VIEW' || action == 'EDIT' || action == 'VIEW-EDIT');
      });
    }).toList();

    Map<String, bool> staffActiveMap = {};
    if (widget.isEdit && widget.accountId != null && widget.accountId!.isNotEmpty) {
      final accountDetailsUrl =
          "http://account.galaxyex.xyz/v1/user/api//account/get-account-details/${widget.accountId}";
      try {
        final accountDetailsResponse = await http.get(Uri.parse(accountDetailsUrl), headers: {
          "Authkey": authKey,
          "Content-Type": "application/json",
        });
        if (accountDetailsResponse.statusCode == 200) {
          final Map<String, dynamic> accountDetailsJson = json.decode(accountDetailsResponse.body);
          final List<dynamic> isDisableList = accountDetailsJson['data']?['isDisable'] ?? [];
          for (final entry in isDisableList) {
            if (entry['userId'] != null && entry['isActive'] != null) {
              staffActiveMap[entry['userId'].toString()] = entry['isActive'] == true;
            }
          }
        }
      } catch (_) {}
    }

    setState(() {
      _staffList = filteredStaff;
      _staffVisibility = {};
      for (int i = 0; i < filteredStaff.length; i++) {
        final staff = filteredStaff[i];
        final userId = (staff['userId'] ?? staff['_id'] ?? staff['id']).toString();
        if (widget.isEdit) {
          _staffVisibility[i] = staffActiveMap.containsKey(userId) ? staffActiveMap[userId]! : false;
        } else {
          _staffVisibility[i] = true;
        }
      }
      _isStaffLoading = false;
    });
  }

  Future<void> _submitCustomer() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
    });

    final prefs = await SharedPreferences.getInstance();
    final authKey = prefs.getString("auth_token");

    final isDisable = _staffList.asMap().entries.map((entry) {
      final staff = entry.value;
      final index = entry.key;
      return {
        "userId": (staff['userId'] ?? staff['_id'] ?? staff['id']).toString(),
        "isActive": _staffVisibility[index] ?? false,
      };
    }).toList();

    final isEdit = widget.isEdit;
    final url = Uri.parse(
      isEdit
          ? 'http://account.galaxyex.xyz/v1/user/api/account/update-account'
          : 'http://account.galaxyex.xyz/v1/user/api/account/add-account',
    );
    final body = isEdit
        ? {
      'customerName': _nameController.text,
      'companyId': widget.companyId,
      'remark': _remarkController.text,
      'accountId': widget.accountId,
      'isDisable': isDisable,
    }
        : {
      'customerName': _nameController.text,
      'companyId': widget.companyId,
      'remark': _remarkController.text,
      'isDisable': isDisable,
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
          SnackBar(content: Text(isEdit
              ? AppStrings.getString("customerUpdatedSuccessfully")
              : AppStrings.getString("customerCreatedSuccessfully"))),
        );
        Navigator.pop(context, true);
      } else {
        String msg = isEdit
            ? AppStrings.getString("failedToUpdateCustomer")
            : AppStrings.getString("failedToCreateCustomer");
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
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Center(child: Text(AppStrings.getString("noStaffAvailable"))),
      );
    }
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
        Padding(
          padding: const EdgeInsets.only(top: 16.0, bottom: 4, left: 2),
          child: Text(
            AppStrings.getString("staffList"),
            style: const TextStyle(
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
              hintText: AppStrings.getString("searchStaff"),
              contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              isDense: true,
            ),
          ),
        ),
        filteredStaff.isEmpty
            ? Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Center(child: Text(AppStrings.getString("noStaffFound"))),
        )
            : Column(
          children: List.generate(filteredStaff.length, (filteredIndex) {
            final staff = filteredStaff[filteredIndex];
            final index = _staffList.indexOf(staff);
            final name = staff['name'] ?? "N/A";
            final loginId = staff['loginId'] ?? "N/A";
            final show = _staffVisibility[index] ?? false;
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
                          "${AppStrings.getString("userId")}: $loginId",
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        show
                            ? AppStrings.getString("show")
                            : AppStrings.getString("hide"),
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
        title: Text(
          isEdit
              ? AppStrings.getString("editCustomer")
              : AppStrings.getString("addCustomer"),
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
                  hintText: AppStrings.getString("customerName"),
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                ),
                validator: (value) =>
                value == null || value.trim().isEmpty
                    ? AppStrings.getString("enterCustomerName")
                    : null,
              ),
              const SizedBox(height: 10),
              Container(
                height: 100,
                child: TextFormField(
                  controller: _remarkController,
                  decoration: InputDecoration(
                    hintText: AppStrings.getString("remark"),
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
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
            label: Text(
              isEdit
                  ? AppStrings.getString("updateCustomer")
                  : AppStrings.getString("createCustomer"),
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