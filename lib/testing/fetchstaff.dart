import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../presentation/addstaff.dart';

class StaffListPage extends StatefulWidget {
  const StaffListPage({super.key});

  @override
  State<StaffListPage> createState() => _StaffListPageState();
}

class _StaffListPageState extends State<StaffListPage> {
  bool isLoading = true;
  String? errorMessage;
  List<dynamic> staffList = [];
  Map<String, String> companyMap = {}; // companyId -> companyName

  @override
  void initState() {
    super.initState();
    fetchStaffList();
  }

  Future<String?> getAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString("auth_token");
  }

  Future<void> fetchCompanyNames() async {
    final url = "http://account.galaxyex.xyz/v1/user/api//account/get-company";
    final authKey = await getAuthToken();
    if (authKey == null) return;
    try {
      final response = await http.get(Uri.parse(url), headers: {
        "Authkey": authKey,
        "Content-Type": "application/json",
      });
      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = json.decode(response.body);
        if (jsonData['meta'] != null && jsonData['meta']['status'] == true) {
          for (var comp in (jsonData['data'] as List? ?? [])) {
            companyMap[comp['companyId'] ?? comp['_id']] = comp['companyName'] ?? '';
          }
        }
      }
    } catch (_) {}
  }

  Future<void> fetchStaffList() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    final url = "http://account.galaxyex.xyz/v1/user/api/user/get-staff";
    final authKey = await getAuthToken();
    if (authKey == null) {
      setState(() {
        errorMessage = "Authentication token missing. Please log in.";
        isLoading = false;
      });
      return;
    }

    await fetchCompanyNames();

    try {
      final response = await http.get(Uri.parse(url), headers: {
        "Authkey": authKey,
        "Content-Type": "application/json",
      });

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = json.decode(response.body);
        if (jsonData['meta'] != null && jsonData['meta']['status'] == true) {
          setState(() {
            staffList = jsonData['data'] ?? [];
            isLoading = false;
          });
        } else {
          setState(() {
            errorMessage = jsonData['meta']?['msg'] ?? "Failed to fetch staff list";
            isLoading = false;
          });
        }
      } else {
        setState(() {
          errorMessage = "Server error: ${response.statusCode}";
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = "Error: $e";
        isLoading = false;
      });
    }
  }

  void showStaffDetails(Map<String, dynamic> staff) {
    showDialog(
      context: context,
      builder: (context) {
        final companyAccess = staff['companyAccess'] as List? ?? [];
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            padding: const EdgeInsets.all(20),
            constraints: const BoxConstraints(maxWidth: 350),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: const Color(0xFF265E85),
                    child: Text(
                      (staff['name'] ?? '').isNotEmpty ? staff['name'][0].toUpperCase() : '',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 32,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    staff['name'] ?? '',
                    style: const TextStyle(
                      color: Color(0xFF265E85),
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  infoRow("UserID", staff['loginId']),
                  infoRow("Password", staff['password']),
                  infoRow("User Type", staff['userType']),
                  if (companyAccess.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Company Access:",
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          ...companyAccess.map((ca) {
                            final cid = ca['companyId'] ?? '';
                            final companyName = companyMap[cid] ?? cid;
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text("• $companyName", style: const TextStyle(fontSize: 13)),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.blue[50],
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      ca['action'] ?? '',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: Color(0xFF265E85),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ],
                      ),
                    ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            // Navigate to AddStaffScreen with staff data for editing
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => AddStaffScreen(
                                  staffData: staff,
                                  onStaffAdded: fetchStaffList,
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.edit, color: Colors.white),
                          label: const Text("Edit", style: TextStyle(color: Colors.white)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF265E85),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text("Close", style: TextStyle(color: Colors.white)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  static Widget infoRow(String label, String? value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("$label: ",
            style: const TextStyle(
                fontWeight: FontWeight.w600, fontSize: 15, color: Colors.black87)),
        Expanded(
          child: Text(value ?? 'N/A',
              style: const TextStyle(fontSize: 15, color: Colors.black54)),
        )
      ],
    ),
  );

  Widget buildStaffItem(Map<String, dynamic> staff) {
    final name = staff['name'] ?? 'N/A';
    final loginId = staff['loginId'] ?? 'N/A';
    final password = staff['password'] ?? '••••••';

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => showStaffDetails(staff),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFF265E85), width: 1),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black12.withOpacity(0.04),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          children: [
            // Circle avatar with initial
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFF265E85),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 22,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            // Name, UserID, Password
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      color: Color(0xFF265E85),
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    "UserID: $loginId",
                    style: const TextStyle(
                      color: Colors.black87,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "Password: $password",
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            // Arrow icon
            Icon(Icons.arrow_forward_ios, color: Colors.grey[500], size: 22),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(color: Colors.white),
        title: const Text("Staff", style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF265E85),
        elevation: 0,
      ),
      backgroundColor: const Color(0xFFF4F6FA),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                Expanded(
                  child: isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : errorMessage != null
                      ? Center(child: Text(errorMessage!))
                      : staffList.isEmpty
                      ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.inbox, size: 60, color: Colors.grey.withOpacity(0.7)),
                        const SizedBox(height: 12),
                        Text(
                          "No staff available, add now",
                          style: TextStyle(fontSize: 17, color: Colors.grey[700]),
                        ),
                      ],
                    ),
                  )
                      : ListView.builder(
                    padding: const EdgeInsets.only(top: 18, bottom: 90),
                    itemCount: staffList.length,
                    itemBuilder: (context, index) => buildStaffItem(staffList[index]),
                  ),
                ),
              ],
            ),
            // Add Staff button at bottom
            Positioned(
              bottom: 18,
              left: 14,
              right: 14,
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.add, color: Colors.white),
                  label: const Text(
                    "Add Staff",
                    style: TextStyle(fontSize: 18, color: Colors.white),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AddStaffScreen(
                          onStaffAdded: fetchStaffList,
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF265E85),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 1,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}