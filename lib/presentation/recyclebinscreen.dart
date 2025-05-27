import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class RecycleBinScreen extends StatefulWidget {
  const RecycleBinScreen({Key? key}) : super(key: key);

  @override
  State<RecycleBinScreen> createState() => _RecycleBinScreenState();
}

class _RecycleBinScreenState extends State<RecycleBinScreen> {
  bool isLoading = true;
  bool isRestoring = false;
  String? restoringLedgerId;
  List<dynamic> recycleLedger = [];
  String? error;

  @override
  void initState() {
    super.initState();
    fetchRecycleLedger();
  }

  Future<String?> getAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString("auth_token");
  }

  Future<void> fetchRecycleLedger() async {
    setState(() {
      isLoading = true;
      error = null;
    });
    final authKey = await getAuthToken();
    if (authKey == null) {
      setState(() {
        error = "Authentication token not found.";
        isLoading = false;
      });
      return;
    }
    try {
      final response = await http.get(
        Uri.parse("http://account.galaxyex.xyz/v1/user/api/setting/recycle-list"),
        headers: {
          "Authkey": authKey,
          "Content-Type": "application/json",
        },
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data["meta"]?["status"] == true) {
          setState(() {
            recycleLedger = data["data"] ?? [];
            isLoading = false;
          });
        } else {
          setState(() {
            error = data["meta"]?["msg"] ?? "Failed to load recycle ledger.";
            isLoading = false;
          });
        }
      } else {
        setState(() {
          error = "Server error: ${response.statusCode}";
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        error = "Error: $e";
        isLoading = false;
      });
    }
  }

  Future<void> restoreLedger(String ledgerId) async {
    setState(() {
      isRestoring = true;
      restoringLedgerId = ledgerId;
    });
    final authKey = await getAuthToken();
    if (authKey == null) {
      _showSnackBar("Authentication token not found.");
      setState(() {
        isRestoring = false;
        restoringLedgerId = null;
      });
      return;
    }
    try {
      final response = await http.get(
        Uri.parse("http://account.galaxyex.xyz/v1/user/api/setting/restore-ledger/$ledgerId"),
        headers: {
          "Authkey": authKey,
          "Content-Type": "application/json",
        },
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data["meta"]?["status"] == true) {
          _showSnackBar("Ledger restored successfully.");
          await fetchRecycleLedger();
        } else {
          _showSnackBar(data["meta"]?["msg"] ?? "Failed to restore ledger.");
        }
      } else {
        _showSnackBar("Server error: ${response.statusCode}");
      }
    } catch (e) {
      _showSnackBar("Error: $e");
    }
    setState(() {
      isRestoring = false;
      restoringLedgerId = null;
    });
  }

  void _showSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  String _formatDate(int millis) {
    final dt = DateTime.fromMillisecondsSinceEpoch(millis);
    return "${dt.day.toString().padLeft(2, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.year}";
  }

  Widget _buildLedgerItem(Map<String, dynamic> entry) {
    final credit = double.tryParse(entry['creditAmount']?.toString() ?? "0") ?? 0;
    final debit = double.tryParse(entry['debitAmount']?.toString() ?? "0") ?? 0;
    final dateMillis = entry['ledgerDate'] ?? 0;
    final remark = entry['remark'] ?? "";
    final ledgerId = entry['ledgerId']?.toString() ?? entry['_id']?.toString() ?? "";
    final bool hasCredit = credit > 0;
    final bool hasDebit = debit > 0;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 3),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            blurRadius: 7,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Date, Credit/Debit, Restore Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Date
              Expanded(
                flex: 3,
                child: Text(
                  _formatDate(dateMillis),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.black,
                  ),
                ),
              ),
              // Credit/Debit
              Expanded(
                flex: 7,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      "Credit: ",
                      style: TextStyle(
                        color: hasCredit ? Colors.green[700] : Colors.grey[700],
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      "₹${credit.toStringAsFixed(2)}",
                      style: TextStyle(
                        color: hasCredit ? Colors.green[700] : Colors.grey[700],
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      "Debit: ",
                      style: TextStyle(
                        color: hasDebit ? Colors.red[700] : Colors.grey[700],
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      "₹${debit.toStringAsFixed(2)}",
                      style: TextStyle(
                        color: hasDebit ? Colors.red[700] : Colors.grey[700],
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (isRestoring && restoringLedgerId == ledgerId)
                      const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.green,
                        ),
                      )
                    else
                      GestureDetector(
                        onTap: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text("Restore Ledger"),
                              content: const Text("Are you sure you want to restore this ledger?"),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(context).pop(false),
                                  child: const Text("Cancel"),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.of(context).pop(true),
                                  child: const Text("Restore", style: TextStyle(color: Colors.green)),
                                ),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            await restoreLedger(ledgerId);
                          }
                        },
                        child: const Icon(Icons.restore, color: Colors.red, size: 22),
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (remark.trim().isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              remark,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.black87,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F3EE),
      appBar: AppBar(
        backgroundColor: const Color(0xFF205781),
        leading: const BackButton(
          color: Colors.white,
        ),
        elevation: 0,
        title: const Text(
          "Recycle Bin",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
        ),
        centerTitle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(22),
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : error != null
            ? Center(child: Text(error!, style: const TextStyle(color: Colors.red)))
            : recycleLedger.isEmpty
            ? const Center(
          child: Text(
            "No ledgers in recycle bin.",
            style: TextStyle(fontSize: 15, color: Colors.grey),
          ),
        )
            : ListView.builder(
          padding: const EdgeInsets.all(10.0),
          itemCount: recycleLedger.length,
          itemBuilder: (context, idx) {
            return _buildLedgerItem(recycleLedger[idx]);
          },
        ),
      ),
    );
  }
}