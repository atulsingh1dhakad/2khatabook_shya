import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../LIST_LANG.dart';
import 'addfollowup.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MaterialApp(
    home: FollowupScreen(),
    debugShowCheckedModeBanner: false,
  ));
}

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

    final url = "http://account.galaxyex.xyz/v1/user/api/setting/get-followup";
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

  Future<void> deleteFollowup(String id) async {
    final authKey = await getAuthToken();
    if (authKey == null) return;
    final url = "http://account.galaxyex.xyz/v1/user/api/setting/delete-followup/$id";
    try {
      final response = await http.delete(
        Uri.parse(url),
        headers: {
          "Authkey": authKey,
          "Content-Type": "application/json",
        },
      );
      if (response.statusCode == 200) {
        await fetchFollowupList();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppStrings.getString("deletedSuccessfully") ?? "Deleted successfully")),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppStrings.getString("deleteFailed") ?? "Delete failed")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.getString("error") ?? "Error: $e")),
      );
    }
  }

  static String _formatDate(dynamic msSinceEpoch) {
    if (msSinceEpoch == null) return '';
    try {
      final dt = DateTime.fromMillisecondsSinceEpoch(msSinceEpoch is int ? msSinceEpoch : int.parse(msSinceEpoch.toString()));
      return "${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}";
    } catch (_) {
      return '';
    }
  }

  Widget buildChatBubble(Map<String, dynamic> followup, {bool isReceived = true}) {
    final name = followup['name'] ?? '';
    final loginId = followup['loginId'] ?? '';
    final remark = followup['remark'] ?? '';
    final date = _formatDate(followup['date']);
    final initials = (name.isNotEmpty) ? name[0].toUpperCase() : "?";
    final id = followup['id']?.toString() ?? followup['_id']?.toString() ?? '';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: isReceived ? MainAxisAlignment.start : MainAxisAlignment.end,
        children: [
          if (isReceived)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: CircleAvatar(
                radius: 20,
                backgroundColor: const Color(0xFF265E85),
                child: Text(
                  initials,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
            ),
          Flexible(
            child: GestureDetector(
              onTap: () => showFollowupDetails(followup),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                margin: const EdgeInsets.only(right: 6),
                decoration: BoxDecoration(
                  color: isReceived ? Colors.white : const Color(0xFF265E85),
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(18),
                    topRight: const Radius.circular(18),
                    bottomLeft: Radius.circular(isReceived ? 0 : 18),
                    bottomRight: Radius.circular(isReceived ? 18 : 0),
                  ),
                  border: Border.all(
                    color: const Color(0xFF265E85).withOpacity(0.3),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.22),
                      blurRadius: 8,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Chat content
                    Expanded(
                      child: Column(
                        crossAxisAlignment: isReceived ? CrossAxisAlignment.start : CrossAxisAlignment.end,
                        children: [
                          Text(
                            name,
                            style: TextStyle(
                              color: isReceived ? const Color(0xFF265E85) : Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (loginId.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                "${AppStrings.getString("userId")}: $loginId",
                                style: TextStyle(
                                  color: isReceived ? Colors.black87 : Colors.white70,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          if (remark.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                "${AppStrings.getString("remark")}: $remark",
                                style: TextStyle(
                                  color: isReceived ? Colors.black54 : Colors.white70,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          if (date.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                date,
                                style: TextStyle(
                                  color: isReceived ? Colors.black38 : Colors.white38,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    // Edit and Delete icons (reduced spacing)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.green, size: 20),
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => AddFollowupScreen(
                                  onFollowupAdded: fetchFollowupList,
                                  followupData: followup, // Add this param in AddFollowupScreen
                                ),
                              ),
                            );
                          },
                          tooltip: AppStrings.getString("edit") ?? "Edit",
                        ),
                        SizedBox(width: 4),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text("Confirm Delete"),
                                content: const Text("Are you sure you want to delete this follow-up?"),
                                actions: [
                                  TextButton(
                                    child: const Text("Cancel"),
                                    onPressed: () => Navigator.pop(ctx, false),
                                  ),
                                  TextButton(
                                    child: const Text("Delete", style: TextStyle(color: Colors.red)),
                                    onPressed: () => Navigator.pop(ctx, true),
                                  ),
                                ],
                              ),
                            );
                            if (confirm == true && id.isNotEmpty) {
                              await deleteFollowup(id);
                            }
                          },
                          tooltip: AppStrings.getString("delete") ?? "Delete",
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (!isReceived)
            Padding(
              padding: const EdgeInsets.only(left: 8.0),
              child: CircleAvatar(
                radius: 20,
                backgroundColor: Colors.grey[400],
                child: const Icon(Icons.person, color: Colors.white),
              ),
            ),
        ],
      ),
    );
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
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => AddFollowupScreen(
                                  onFollowupAdded: fetchFollowupList,
                                  followupData: followup, // Add this param in AddFollowupScreen
                                ),
                              ),
                            );
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
                    Icon(Icons.chat_bubble_outline, size: 60, color: Colors.grey.withOpacity(0.7)),
                    const SizedBox(height: 12),
                    Text(
                      AppStrings.getString("noFollowupAvailableAddNow") ?? "No follow-up available, add now!",
                      style: TextStyle(fontSize: 17, color: Colors.grey[700]),
                    ),
                  ],
                ),
              )
                  : ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
                itemCount: followupList.length,
                itemBuilder: (context, index) {
                  // All followup bubbles appear as received (left-aligned)
                  return buildChatBubble(followupList[index], isReceived: true);
                },
              ),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: SizedBox(
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
            ),
            const SizedBox(height: 16), // bottom spacing
          ],
        ),
      ),
    );
  }
}