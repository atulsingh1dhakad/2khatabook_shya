import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../LIST_LANG.dart';
import 'addfollowup.dart';

class FollowupScreen extends StatefulWidget {
  final VoidCallback? onStaffAdded;
  final Map<String, dynamic>? staffData;

  const FollowupScreen({super.key, this.onStaffAdded, this.staffData});

  @override
  State<FollowupScreen> createState() => _FollowupScreenState();
}

class _FollowupScreenState extends State<FollowupScreen> {
  bool isLoading = true;
  String? errorMessage;
  List<dynamic> followupList = [];

  @override
  void initState() {
    super.initState();
    fetchFollowupList();
  }

  Future<String?> getAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString("auth_token");
  }

  Future<void> fetchFollowupList() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    final url = "http://128.199.21.76:3033/api/setting/get-followup";
    final authKey = await getAuthToken();
    if (authKey == null) {
      setState(() {
        errorMessage = AppStrings.getString("authTokenMissing");
        isLoading = false;
      });
      return;
    }

    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {
          "Authkey": authKey,
          "Content-Type": "application/json",
        },
      );
      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = json.decode(response.body);
        if (jsonData['meta'] != null && jsonData['meta']['status'] == true) {
          setState(() {
            followupList = jsonData['data'] ?? [];
            isLoading = false;
          });
        } else {
          setState(() {
            errorMessage = jsonData['meta']?['msg'] ?? AppStrings.getString("failedToFetchStaffList");
            isLoading = false;
          });
        }
      } else {
        setState(() {
          errorMessage = "${AppStrings.getString("serverError")}: ${response.statusCode}";
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = "${AppStrings.getString("error")}: $e";
        isLoading = false;
      });
    }
  }

  void showFollowupDetails(Map<String, dynamic> followup) {
    showDialog(
      context: context,
      builder: (context) {
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
                      (followup['name'] ?? '').isNotEmpty ? followup['name'][0].toUpperCase() : '',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 32,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    followup['name'] ?? '',
                    style: const TextStyle(
                      color: Color(0xFF265E85),
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  infoRow(AppStrings.getString("userId"), followup['loginId']),
                  infoRow(AppStrings.getString("userType"), followup['userType']),
                  infoRow(AppStrings.getString("remark"), followup['remark']),
                  infoRow("Date", _formatDate(followup['date'])),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            // Optionally add edit functionality here
                          },
                          icon: const Icon(Icons.edit, color: Colors.white),
                          label: Text(AppStrings.getString("edit"), style: const TextStyle(color: Colors.white)),
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
                          child: Text(AppStrings.getString("close"), style: const TextStyle(color: Colors.white)),
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

  Widget buildFollowupItem(Map<String, dynamic> followup) {
    final name = followup['name'] ?? 'N/A';
    final loginId = followup['loginId'] ?? 'N/A';
    final remark = followup['remark'] ?? '';
    final date = _formatDate(followup['date']);

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => showFollowupDetails(followup),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 12),
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
                    "${AppStrings.getString("userId")}: $loginId",
                    style: const TextStyle(
                      color: Colors.black87,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "${AppStrings.getString("remark")}: $remark",
                    style: const TextStyle(
                      color: Colors.black54,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "Date: $date",
                    style: const TextStyle(
                      color: Colors.black54,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: Colors.grey[500], size: 22),
          ],
        ),
      ),
    );
  }

  static String _formatDate(dynamic msSinceEpoch) {
    if (msSinceEpoch == null) return 'N/A';
    try {
      final dt = DateTime.fromMillisecondsSinceEpoch(msSinceEpoch is int ? msSinceEpoch : int.parse(msSinceEpoch.toString()));
      return "${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}";
    } catch (_) {
      return 'N/A';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(color: Colors.white),
        title: Text(AppStrings.getString("followUp") ?? "Follow Up", style: const TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF265E85),
        elevation: 0,
      ),
      backgroundColor: const Color(0xFFF4F6FA),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Column(
            children: [
              Expanded(
                child: isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : errorMessage != null
                    ? Center(child: Text(errorMessage!))
                    : followupList.isEmpty
                    ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.inbox, size: 60, color: Colors.grey.withOpacity(0.7)),
                      const SizedBox(height: 12),
                      Text(
                        AppStrings.getString("noFollowupAvailableAddNow") ?? "No follow-up available, add now!",
                        style: TextStyle(fontSize: 17, color: Colors.grey[700]),
                      ),
                    ],
                  ),
                )
                    : ListView.builder(
                  padding: const EdgeInsets.only(top: 18, bottom: 12),
                  itemCount: followupList.length,
                  itemBuilder: (context, index) => buildFollowupItem(followupList[index]),
                ),
              ),
              const SizedBox(height: 6),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.add, color: Colors.white),
                  label: Text(
                    AppStrings.getString("addFollowup") ?? "Add Follow Up",
                    style: const TextStyle(fontSize: 18, color: Colors.white),
                  ),
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AddFollowupScreen(
                          onFollowupAdded: fetchFollowupList,
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
              const SizedBox(height: 16), // bottom spacing
            ],
          ),
        ),
      ),
    );
  }
}