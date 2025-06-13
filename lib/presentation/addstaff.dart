import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../LIST_LANG.dart';

class AddStaffScreen extends StatefulWidget {
  final VoidCallback? onStaffAdded;
  final Map<String, dynamic>? staffData;

  const AddStaffScreen({
    Key? key,
    this.onStaffAdded,
    this.staffData,
  }) : super(key: key);

  @override
  State<AddStaffScreen> createState() => _AddStaffScreenState();
}

class _AddStaffScreenState extends State<AddStaffScreen> {
  final _formKey = GlobalKey<FormState>();
  final nameController = TextEditingController();
  final userIdController = TextEditingController();
  final passwordController = TextEditingController();
  final searchController = TextEditingController();

  Map<String, bool> selectedCompanies = {};
  Map<String, String> companyActions = {};
  List<Map<String, dynamic>> companyList = [];
  List<Map<String, dynamic>> filteredCompanyList = [];
  bool loading = false;
  bool fetchingCompanies = true;
  bool isEditMode = false;
  String? staffIdToUpdate;

  @override
  void initState() {
    super.initState();
    isEditMode = widget.staffData != null;
    fetchCompanies().then((_) {
      if (isEditMode) {
        prefillFromStaffData(widget.staffData!);
      }
    });
    searchController.addListener(onSearchChanged);
  }

  @override
  void dispose() {
    searchController.removeListener(onSearchChanged);
    searchController.dispose();
    nameController.dispose();
    userIdController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  void prefillFromStaffData(Map<String, dynamic> staff) {
    nameController.text = staff['name'] ?? '';
    userIdController.text = staff['loginId'] ?? '';
    passwordController.text = staff['password'] ?? '';
    staffIdToUpdate = staff['userId']?.toString() ?? staff['_id']?.toString() ?? staff['id']?.toString();
    final List accessList = staff['companyAccess'] ?? [];
    for (var company in companyList) {
      final id = company['companyId'] ?? company['_id'];
      selectedCompanies[id] = false;
      companyActions[id] = "view";
    }
    for (var ca in accessList) {
      final id = ca['companyId'];
      selectedCompanies[id] = true;
      companyActions[id] = (ca['action'] ?? "view").toString().toLowerCase();
    }
    setState(() {});
  }

  void onSearchChanged() {
    final query = searchController.text.trim().toLowerCase();
    setState(() {
      if (query.isEmpty) {
        filteredCompanyList = List<Map<String, dynamic>>.from(companyList);
      } else {
        filteredCompanyList = companyList.where((company) {
          final name = (company['companyName'] ?? '').toString().toLowerCase();
          return name.contains(query);
        }).toList();
      }
    });
  }

  Future<String?> getAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString("auth_token");
  }

  Future<void> fetchCompanies() async {
    setState(() {
      fetchingCompanies = true;
    });
    final url = "http://account.galaxyex.xyz/v1/user/api/account/get-company";
    final authKey = await getAuthToken();
    if (authKey == null) {
      setState(() {
        fetchingCompanies = false;
      });
      return;
    }
    try {
      final response = await http.get(Uri.parse(url), headers: {
        "Authkey": authKey,
        "Content-Type": "application/json",
      });
      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = json.decode(response.body);
        if (jsonData['meta'] != null &&
            jsonData['meta']['status'] == true &&
            jsonData['data'] is List) {
          companyList = List<Map<String, dynamic>>.from(jsonData['data'] ?? []);
          filteredCompanyList = List<Map<String, dynamic>>.from(companyList);
          for (var company in companyList) {
            final id = company['companyId'] ?? company['_id'];
            selectedCompanies.putIfAbsent(id, () => false);
            companyActions.putIfAbsent(id, () => "view");
          }
        }
      }
    } catch (_) {}
    setState(() {
      fetchingCompanies = false;
    });
  }

  Future<void> addOrUpdateStaff() async {
    if (!_formKey.currentState!.validate()) return;
    List<Map<String, String>> companyAccess = [];
    selectedCompanies.forEach((id, isSelected) {
      if (isSelected && (companyActions[id] != null)) {
        companyAccess.add({
          "companyId": id,
          "action": companyActions[id]!.toUpperCase(),
        });
      }
    });
    if (companyAccess.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.getString("selectAtLeastOneCompany"))),
      );
      return;
    }
    setState(() => loading = true);

    final payload = {
      "name": nameController.text.trim(),
      "loginId": userIdController.text.trim(),
      "password": passwordController.text.trim(),
      "companyAccess": companyAccess,
      if (isEditMode && staffIdToUpdate != null) "userIdToUpdate": staffIdToUpdate,
    };

    final authKey = await getAuthToken();
    if (authKey == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.getString("authTokenMissing"))),
      );
      setState(() => loading = false);
      return;
    }

    final String url = isEditMode
        ? "http://account.galaxyex.xyz/v1/user/api/user/update-user"
        : "http://account.galaxyex.xyz/v1/user/api/user/add-user";

    final response = await http.post(
      Uri.parse(url),
      headers: {
        "Authkey": authKey,
        "Content-Type": "application/json",
      },
      body: jsonEncode(payload),
    );
    setState(() => loading = false);

    if (response.statusCode == 200) {
      final jsonData = json.decode(response.body);
      if (jsonData['meta'] != null && jsonData['meta']['status'] == true) {
        if (widget.onStaffAdded != null) widget.onStaffAdded!();
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isEditMode
              ? AppStrings.getString("staffUpdatedSuccessfully")
              : AppStrings.getString("staffAddedSuccessfully"))),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(jsonData['meta']?['msg'] ?? AppStrings.getString(isEditMode ? "failedToUpdateStaff" : "failedToAddStaff"))),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("${AppStrings.getString("serverError")}: ${response.statusCode}")),
      );
    }
  }

  Widget _companyActionDropdown(String id) {
    return SizedBox(
      width: 92,
      child: DropdownButtonFormField<String>(
        value: companyActions[id],
        isExpanded: true,
        icon: const Icon(Icons.arrow_drop_down, size: 18),
        decoration: const InputDecoration(
          border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
          isDense: true,
          contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        ),
        items: [
          DropdownMenuItem(
            value: 'view',
            child: Row(
              children: [
                const Icon(Icons.visibility, size: 13),
                const SizedBox(width: 4),
                Text(AppStrings.getString("view"), style: const TextStyle(fontSize: 12)),
              ],
            ),
          ),
          DropdownMenuItem(
            value: 'view-edit',
            child: Row(
              children: [
                const Icon(Icons.edit, size: 13),
                const SizedBox(width: 4),
                Text(AppStrings.getString("edit"), style: const TextStyle(fontSize: 12)),
              ],
            ),
          ),
        ],
        onChanged: (val) {
          setState(() {
            companyActions[id] = val ?? "view";
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditMode
            ? AppStrings.getString("editStaff")
            : AppStrings.getString("addStaff"),
            style: const TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF265E85),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: fetchingCompanies
          ? const Center(child: CircularProgressIndicator())
          : AbsorbPointer(
        absorbing: loading,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(18),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: AppStrings.getString("name"),
                    prefixIcon: const Icon(Icons.person_outline),
                  ),
                  validator: (v) =>
                  (v == null || v.trim().isEmpty) ? AppStrings.getString("nameRequired") : null,
                ),
                TextFormField(
                  controller: userIdController,
                  decoration: InputDecoration(
                    labelText: AppStrings.getString("userId"),
                    prefixIcon: const Icon(Icons.badge_outlined),
                  ),
                  validator: (v) =>
                  (v == null || v.trim().isEmpty) ? AppStrings.getString("userIdRequired") : null,
                  enabled: !isEditMode,
                ),
                TextFormField(
                  controller: passwordController,
                  decoration: InputDecoration(
                    labelText: AppStrings.getString("password"),
                    prefixIcon: const Icon(Icons.lock_outline),
                  ),
                  validator: (v) =>
                  (v == null || v.trim().isEmpty) ? AppStrings.getString("passwordRequired") : null,
                  obscureText: true,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: searchController,
                  decoration: InputDecoration(
                    labelText: AppStrings.getString("searchCompanyByName"),
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  AppStrings.getString("selectCompaniesAndActions"),
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16),
                ),
                ...filteredCompanyList.map((company) {
                  final id = company['companyId'] ?? company['_id'];
                  final name = company['companyName'] ?? '';
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Checkbox(
                        value: selectedCompanies[id] ?? false,
                        onChanged: (val) {
                          setState(() {
                            selectedCompanies[id] = val ?? false;
                          });
                        },
                      ),
                      Expanded(
                        child: Text(
                          name,
                          style: const TextStyle(fontSize: 15),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _companyActionDropdown(id),
                    ],
                  );
                }).toList(),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: loading ? null : addOrUpdateStaff,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: loading
                        ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                        : Text(isEditMode
                        ? AppStrings.getString("saveChanges")
                        : AppStrings.getString("save"),
                        style: const TextStyle(color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}