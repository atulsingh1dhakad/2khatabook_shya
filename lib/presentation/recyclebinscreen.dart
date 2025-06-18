import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../LIST_LANG.dart';

// UI constants
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

  String _selectedLang = "en";
  @override
  void initState() {
    super.initState();
    _loadSelectedLanguage();
    fetchRecycleLedger();
  }

  Future<void> _loadSelectedLanguage() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? lang = prefs.getString("app_language");
    setState(() {
      _selectedLang = lang ?? "en";
      AppStrings.setLanguage(_selectedLang);
    });
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
        error = AppStrings.getString("authErrorRelogin");
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
          List<dynamic> enriched = await _enrichWithCustomerNames(entries, authKey);
          setState(() {
            recycleLedger = enriched;
            isLoading = false;
          });
        } else {
          setState(() {
            error = data["meta"]?["msg"] ?? AppStrings.getString("failedToLoadRecycleBin");
            isLoading = false;
          });
        }
      } else {
        setState(() {
          error = "${AppStrings.getString("serverError")}: ${response.statusCode}";
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        error = "${AppStrings.getString("error")}: $e";
        isLoading = false;
      });
    }
  }

  Future<List<dynamic>> _enrichWithCustomerNames(List<dynamic> entries, String authKey) async {
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
          entry['customerName'] = jsonData['data']?['name'] ?? AppStrings.getString("customerName");
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
      _showSnackBar(AppStrings.getString("authErrorRelogin"));
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
          _showSnackBar(AppStrings.getString("undo"));
          await fetchRecycleLedger();
        } else {
          _showSnackBar(data["meta"]?["msg"] ?? AppStrings.getString("failedToRestoreLedger"));
        }
      } else {
        _showSnackBar("${AppStrings.getString("serverError")}: ${response.statusCode}");
      }
    } catch (e) {
      _showSnackBar("${AppStrings.getString("error")}: $e");
    }
    setState(() {
      isRestoring = false;
      restoringLedgerId = null;
    });
  }

  Future<void> deleteLedger(String ledgerId) async {
    final authKey = await getAuthToken();
    if (authKey == null) {
      _showSnackBar(AppStrings.getString("authErrorRelogin"));
      return;
    }
    try {
      final response = await http.get(
        Uri.parse("http://account.galaxyex.xyz/v1/user/api/setting/delet-recycle/$ledgerId"),
        headers: {
          "Authkey": authKey,
          "Content-Type": "application/json",
        },
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data["meta"]?["status"] == true) {
          _showSnackBar(data["meta"]?["msg"] ?? AppStrings.getString("delete"));
          await fetchRecycleLedger();
        } else {
          _showSnackBar(data["meta"]?["msg"] ?? AppStrings.getString("failedToDeleteBackup"));
        }
      } else {
        _showSnackBar("${AppStrings.getString("serverError")}: ${response.statusCode}");
      }
    } catch (e) {
      _showSnackBar("${AppStrings.getString("error")}: $e");
    }
  }

  Future<void> deleteAllLedgers() async {
    if (recycleLedger.isEmpty) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppStrings.getString("deleteAllPermanently")),
        content: Text(AppStrings.getString("confirmDeleteAllPermanently")),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(AppStrings.getString("cancel")),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(AppStrings.getString("deleteAll"), style: const TextStyle(color: Colors.red)),
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
      _showSnackBar(AppStrings.getString("authErrorRelogin"));
      setState(() {
        isDeletingAll = false;
      });
      return;
    }
    try {
      // Use the dedicated API for deleting all recycle entries
      final response = await http.get(
        Uri.parse("http://account.galaxyex.xyz/v1/user/api/setting/delet-all-recycle"),
        headers: {
          "Authkey": authKey,
          "Content-Type": "application/json",
        },
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data["meta"]?["status"] == true) {
          _showSnackBar(data["meta"]?["msg"] ?? AppStrings.getString("deleteAllPermanently"));
          await fetchRecycleLedger();
        } else {
          _showSnackBar(data["meta"]?["msg"] ?? AppStrings.getString("failedToDeleteBackup"));
        }
      } else {
        _showSnackBar("${AppStrings.getString("serverError")}: ${response.statusCode}");
      }
    } catch (e) {
      _showSnackBar("${AppStrings.getString("error")}: $e");
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
      ago = AppStrings.getString("justNow");
    } else if (diff.inMinutes < 60) {
      ago = AppStrings.getString("minutesAgo").replaceFirst("{n}", "${diff.inMinutes}");
    } else if (diff.inHours < 24) {
      ago = AppStrings.getString("hoursAgo").replaceFirst("{n}", "${diff.inHours}");
    } else {
      ago = AppStrings.getString("daysAgo").replaceFirst("{n}", "${diff.inDays}");
    }
    return isEntry
        ? AppStrings.getString("entryDeleted").replaceFirst("{time}", ago)
        : AppStrings.getString("customerDeleted").replaceFirst("{time}", ago);
  }

  Widget _buildLeading(Map<String, dynamic> entry) {
    return CircleAvatar(
      radius: 22,
      backgroundColor: const Color(0xFFE6ECF5),
      child: const Icon(Icons.person_outlined, color: Color(0xFF2D486C), size: 28),
    );
  }

  String formatAmount(num amt) {
    String s = amt.abs().toStringAsFixed(0);
    if (s.length <= 3) return amt >= 0 ? "₹ $s" : "-₹ $s";
    String last3 = s.substring(s.length - 3);
    String rest = s.substring(0, s.length - 3);
    rest = rest.replaceAllMapped(RegExp(r'\B(?=(\d{2})+(?!\d))'), (match) => ",");
    return (amt < 0 ? "-₹ " : "₹ ") + rest + (rest.isNotEmpty ? "," : "") + last3;
  }

  Color amountColor(num amt) => amt >= 0 ? const Color(0xFF205781) : const Color(0xFFFF0000);

  String youLabel(num amt) => amt >= 0 ? AppStrings.getString("youWillGet") : AppStrings.getString("youWillGive");

  Widget buildLedgerItem(Map<String, dynamic> entry) {
    final credit = double.tryParse(entry['creditAmount']?.toString() ?? "0") ?? 0;
    final debit = double.tryParse(entry['debitAmount']?.toString() ?? "0") ?? 0;
    final amount = credit > 0 ? credit : -debit;
    final name = entry['customerName'] ?? entry['name'] ?? AppStrings.getString("customerName");
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
                            isEntry
                                ? AppStrings.getString("entryFrom").replaceFirst("{source}", entrySource)
                                : AppStrings.getString("customerFrom").replaceFirst("{source}", entrySource),
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

            const Divider(),
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
                          title: Text(AppStrings.getString("undoDelete")),
                          content: Text(AppStrings.getString("confirmUndoDelete")),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(false),
                              child: Text(AppStrings.getString("cancel")),
                            ),
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(true),
                              child: Text(AppStrings.getString("undo"), style: const TextStyle(color: Color(0xFF2D486C))),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        await restoreLedger(ledgerId);
                      }
                    },
                    icon: const Icon(Icons.settings_backup_restore_rounded, size: 20),
                    label: Text(AppStrings.getString("undo")),
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
                          title: Text(AppStrings.getString("deletePermanently")),
                          content: Text(AppStrings.getString("confirmDeletePermanently")),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(false),
                              child: Text(AppStrings.getString("cancel")),
                            ),
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(true),
                              child: Text(AppStrings.getString("delete"), style: const TextStyle(color: Colors.red)),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        await deleteLedger(ledgerId);
                      }
                    },
                    icon: const Icon(Icons.delete, size: 18),
                    label: Text(AppStrings.getString("delete")),
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
    AppStrings.setLanguage(_selectedLang);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F3EE),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: AppBar(
          backgroundColor: const Color(0xFF265E85),
          leading: const BackButton(color: Colors.white),
          elevation: 0,
          title: Text(
            AppStrings.getString("recycleBin"),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
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
            ? Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.inbox, size: 60, color: Colors.grey),
              const SizedBox(height: 12),
              Text(
                AppStrings.getString("noEntryAvailable"),
                style: const TextStyle(fontSize: kFontLarge, color: Colors.grey),
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
                : Text(
              AppStrings.getString("deleteAllPermanently"),
              style: const TextStyle(
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