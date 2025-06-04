import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// UI constants based on the image
const double kFontSmall = 12.0;
const double kFontMedium = 15.0;
const double kFontLarge = 17.0;

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
  bool isDeletingAll = false;

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
          List<dynamic> entries = data["data"] ?? [];
          // Fetch customer names for entries that require it, in parallel for speed
          List<dynamic> enriched = await _enrichWithCustomerNames(entries, authKey);
          setState(() {
            recycleLedger = enriched;
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

  Future<List<dynamic>> _enrichWithCustomerNames(List<dynamic> entries, String authKey) async {
    // Parallel fetching of missing customer names for speed
    List<Future<void>> futures = [];
    for (final entry in entries) {
      if ((entry['customerName'] == null || entry['customerName'].toString().trim().isEmpty) &&
          (entry['accountId'] != null && entry['accountId'].toString().isNotEmpty)) {
        futures.add(_fetchAndSetCustomerName(entry, authKey));
      }
    }
    await Future.wait(futures);
    return entries;
  }

  Future<void> _fetchAndSetCustomerName(Map<String, dynamic> entry, String authKey) async {
    try {
      final resp = await http.get(
        Uri.parse("http://account.galaxyex.xyz/v1/user/api//account/get-account-details/${entry['accountId']}"),
        headers: {
          "Authkey": authKey,
          "Content-Type": "application/json",
        },
      );
      if (resp.statusCode == 200) {
        final jsonData = json.decode(resp.body);
        if (jsonData['meta'] != null && jsonData['meta']['status'] == true) {
          entry['customerName'] = jsonData['data']?['name'] ?? "Customer";
        }
      }
    } catch (_) {
      // Ignore errors, fallback to default
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

  Future<void> deleteLedger(String ledgerId) async {
    _showSnackBar("Permanent delete not implemented.");
    // After deletion, refresh the bin:
    // await fetchRecycleLedger();
  }

  Future<void> deleteAllLedgers() async {
    if (recycleLedger.isEmpty) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete All Permanently"),
        content: const Text("Are you sure you want to permanently delete all items in the recycle bin? This action cannot be undone."),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text("Delete All", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() {
      isDeletingAll = true;
    });
    final authKey = await getAuthToken();
    if (authKey == null) {
      _showSnackBar("Authentication token not found.");
      setState(() {
        isDeletingAll = false;
      });
      return;
    }
    try {
      // Assuming a bulk delete API exists; if not, delete one by one
      // Here, we just delete each ledger one by one for demonstration
      for (final entry in recycleLedger) {
        final ledgerId = entry['ledgerId']?.toString() ?? entry['_id']?.toString() ?? "";
        if (ledgerId.isNotEmpty) {
          // Implement actual delete call here when API is available
        }
      }
      _showSnackBar("Permanent delete of all items is not implemented (demo).");
      // After deletion, refresh the bin:
      // await fetchRecycleLedger();
    } catch (e) {
      _showSnackBar("Error: $e");
    }
    setState(() {
      isDeletingAll = false;
    });
  }

  void _showSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  String _getTimeAgoLabel(int timestampMillis, bool isEntry) {
    final now = DateTime.now();
    final deleted = DateTime.fromMillisecondsSinceEpoch(timestampMillis);
    final diff = now.difference(deleted);
    String ago;
    if (diff.inMinutes < 1) {
      ago = "just now";
    } else if (diff.inMinutes < 60) {
      ago = "${diff.inMinutes} minutes ago";
    } else if (diff.inHours < 24) {
      ago = "${diff.inHours} hours ago";
    } else {
      ago = "${diff.inDays} days ago";
    }
    return isEntry
        ? "Entry deleted $ago"
        : "Customer deleted $ago";
  }

  // Returns a leading icon based on type
  Widget _buildLeading(Map<String, dynamic> entry) {
    return CircleAvatar(
      radius: 22,
      backgroundColor: const Color(0xFFE6ECF5),
      child: const Icon(Icons.person_outlined, color: Color(0xFF2D486C), size: 28),
    );
  }

  // Format ₹ 432,750 style
  String formatAmount(num amt) {
    String s = amt.abs().toStringAsFixed(0);
    if (s.length <= 3) return amt >= 0 ? "₹ $s" : "-₹ $s";
    String last3 = s.substring(s.length - 3);
    String rest = s.substring(0, s.length - 3);
    rest = rest.replaceAllMapped(RegExp(r'\B(?=(\d{2})+(?!\d))'), (match) => ",");
    return (amt < 0 ? "-₹ " : "₹ ") + rest + (rest.isNotEmpty ? "," : "") + last3;
  }

  Color amountColor(num amt) => amt >= 0 ? const Color(0xFF205781) : const Color(0xFFFF0000);

  String youLabel(num amt) => amt >= 0 ? "You will get" : "You will give";

  Widget buildLedgerItem(Map<String, dynamic> entry) {
    final credit = double.tryParse(entry['creditAmount']?.toString() ?? "0") ?? 0;
    final debit = double.tryParse(entry['debitAmount']?.toString() ?? "0") ?? 0;
    final amount = credit > 0 ? credit : -debit;
    final isCredit = credit > 0;
    final name = entry['customerName'] ?? entry['name'] ?? "Customer";
    final ledgerId = entry['ledgerId']?.toString() ?? entry['_id']?.toString() ?? "";
    final deletedTime = entry['deleteDate'] ?? entry['deletedAt'] ?? entry['ledgerDate'] ?? DateTime.now().millisecondsSinceEpoch;
    final isEntry = entry.containsKey('creditAmount') || entry.containsKey('debitAmount');
    final entrySource = entry['source'] ?? entry['remark'] ?? "";
    final deletedLabel = _getTimeAgoLabel(deletedTime, isEntry);

    return Card(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 5, top: 5, left: 5, right: 5),
      elevation: 6,
      shadowColor: Colors.black.withOpacity(0.20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildLeading(entry),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: kFontLarge,
                          color: Color(0xFF2D486C),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          const Icon(Icons.delete_outline, size: 15, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(
                            deletedLabel,
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                      if (entrySource.toString().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            isEntry ? "Entry from $entrySource" : "Customer from $entrySource",
                            style: TextStyle(color: Colors.black54, fontSize: kFontSmall),
                          ),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 12, right: 2, top: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        formatAmount(amount),
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: amountColor(amount),
                        ),
                      ),
                      Text(
                        youLabel(amount),
                        style: TextStyle(
                          color: amountColor(amount),
                          fontWeight: FontWeight.w500,
                          fontSize: 11,
                        ),
                      )
                    ],
                  ),
                ),
              ],
            ),

            Divider(),
            Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF2D486C),
                      textStyle: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    onPressed: isRestoring && restoringLedgerId == ledgerId
                        ? null
                        : () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text("Undo Delete"),
                          content: const Text("Are you sure you want to restore this item?"),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(false),
                              child: const Text("Cancel"),
                            ),
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(true),
                              child: const Text("Undo", style: TextStyle(color: Color(0xFF2D486C))),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        await restoreLedger(ledgerId);
                      }
                    },
                    icon: const Icon(Icons.settings_backup_restore_rounded, size: 20),
                    label: const Text("Undo"),
                  ),
                ),
                Expanded(
                  child: TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.red,
                      textStyle: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    onPressed: isRestoring && restoringLedgerId == ledgerId
                        ? null
                        : () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text("Delete Permanently"),
                          content: const Text("Are you sure you want to permanently delete this item?"),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(false),
                              child: const Text("Cancel"),
                            ),
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(true),
                              child: const Text("Delete", style: TextStyle(color: Colors.red)),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        await deleteLedger(ledgerId);
                      }
                    },
                    icon: const Icon(Icons.delete, size: 18),
                    label: const Text("Delete"),
                  ),
                ),
              ],
            ),
          ],
        ),
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
          leading: const BackButton(color: Colors.white),
          elevation: 0,
          title: const Text(
            "Recycle Bin",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
          ),
          centerTitle: true,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(22)),
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
          padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
          itemCount: recycleLedger.length,
          itemBuilder: (context, idx) {
            return buildLedgerItem(recycleLedger[idx]);
          },
        ),
      ),
      bottomNavigationBar: recycleLedger.isNotEmpty
          ? SafeArea(
        child: Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: OutlinedButton.icon(
            icon: const Icon(Icons.delete_forever, color: Colors.red),
            label: isDeletingAll
                ? const SizedBox(
              width: 25,
              height: 25,
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
                strokeWidth: 2,
              ),
            )
                : const Text(
              "Delete All Permanently",
              style: TextStyle(
                color: Colors.red,
                fontSize: kFontLarge,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: OutlinedButton.styleFrom(
              backgroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(5),
              ),
              side: const BorderSide(color: Colors.red, width: 1.5),
            ),
            onPressed: isDeletingAll
                ? null
                : () {
              deleteAllLedgers();
            },
          ),
        ),
      )
          : null,
    );
  }
}