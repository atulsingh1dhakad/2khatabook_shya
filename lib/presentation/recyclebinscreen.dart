import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// Font sizes and styles copied from CustomerDetails
const double kFontSmall = 12;
const double kFontMedium = 16;
const double kFontLarge = 12;
const double kFontXLarge = 12;

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

  String formatDateTime(int milliseconds) {
    final dt = DateTime.fromMillisecondsSinceEpoch(milliseconds);
    int hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    String ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return "${dt.day.toString().padLeft(2, '0')} "
        "${_monthName(dt.month)} "
        "${dt.year} "
        "$hour:${dt.minute.toString().padLeft(2, '0')}$ampm";
  }

  String _monthName(int month) {
    const months = [
      "Jan", "Feb", "Mar", "Apr", "May", "Jun",
      "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"
    ];
    return months[(month - 1).clamp(0, 11)];
  }

  Widget buildLedgerItem(Map<String, dynamic> entry) {
    final credit = double.tryParse(entry['creditAmount']?.toString() ?? "0") ?? 0;
    final debit = double.tryParse(entry['debitAmount']?.toString() ?? "0") ?? 0;
    final dateMillis = entry['ledgerDate'] ?? 0;
    final remark = entry['remark'] ?? "";
    final ledgerId = entry['ledgerId']?.toString() ?? entry['_id']?.toString() ?? "";
    final isCredit = credit > 0;
    final isDebit = debit > 0;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Date & left details
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  formatDateTime(dateMillis),
                  style: const TextStyle(
                      fontWeight: FontWeight.w400, fontSize: kFontSmall),
                ),
                if (isCredit)
                  Container(
                    decoration: BoxDecoration(
                        borderRadius: BorderRadius.all(Radius.circular(20)),
                        color: Color(0xfffad0c44d).withOpacity(0.1)
                    ),
                    child: Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        "₹${credit.toStringAsFixed(2)}",
                        style: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.w400,
                          fontSize: kFontSmall,
                        ),
                      ),
                    ),
                  ),
                if (isDebit)
                  Container(
                    decoration: BoxDecoration(
                        borderRadius: BorderRadius.all(Radius.circular(20)),
                        color: Color(0xfffad0c44d).withOpacity(0.1)
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(2),
                      child: Text(
                        "₹${debit.toStringAsFixed(2)}",
                        style: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.w400,
                          fontSize: kFontSmall,
                        ),
                      ),
                    ),
                  ),
                if (remark.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      remark,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // Debit
          Container(
            color: const Color(0xffd63384).withOpacity(0.05),
            width: 70,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 3),
            child: Text(
              "₹${debit.toStringAsFixed(2)}",
              style: const TextStyle(
                  fontWeight: FontWeight.w400,
                  fontSize: kFontLarge),
            ),
          ),
          // Credit
          Container(
            width: 75,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 3),
            child: Text(
              "₹${credit.toStringAsFixed(2)}",
              style: const TextStyle(
                  fontWeight: FontWeight.w400,
                  fontSize: kFontLarge),
            ),
          ),
          // Flexible gap
          const Spacer(),
          // Restore icon
          Padding(
            padding: const EdgeInsets.only(right: 12, left: 8),
            child: isRestoring && restoringLedgerId == ledgerId
                ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.green,
              ),
            )
                : GestureDetector(
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
              child: const Icon(Icons.restore, color: Colors.green, size: 22),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F3EE),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: AppBar(
          backgroundColor: const Color(0xFF265E85),
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
      ),
      body: SafeArea(
        top: false,
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : error != null
            ? Center(child: Text(error!, style: const TextStyle(color: Colors.red)))
            : recycleLedger.isEmpty
            ? const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.inbox, size: 60, color: Colors.grey),
              SizedBox(height: 12),
              Text(
                "No ledgers in recycle bin.",
                style: TextStyle(fontSize: kFontLarge, color: Colors.grey),
              ),
            ],
          ),
        )
            : ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
          itemCount: recycleLedger.length,
          itemBuilder: (context, idx) {
            return buildLedgerItem(recycleLedger[idx]);
          },
        ),
      ),
    );
  }
}