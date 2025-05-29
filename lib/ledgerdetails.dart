import 'dart:convert';
import 'package:Calculator/presentation/youwillget.dart';
import 'package:Calculator/presentation/youwillgive.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const double kFontSmall = 14;
const double kFontMedium = 16;
const double kFontLarge = 18;
const double kFontXLarge = 20;

class LedgerDetails extends StatefulWidget {
  final String ledgerId;
  final String accountName;
  final String accountImageUrl;
  final String companyId;
  final String accountId;

  const LedgerDetails({
    Key? key,
    required this.ledgerId,
    required this.accountName,
    required this.companyId,
    required this.accountId,
    this.accountImageUrl = '',
  }) : super(key: key);

  @override
  State<LedgerDetails> createState() => _LedgerDetailsState();
}

class _LedgerDetailsState extends State<LedgerDetails> {
  bool isLoading = true;
  String? errorMessage;
  Map<String, dynamic>? ledgerEntry;
  Map<String, dynamic>? totals;

  @override
  void initState() {
    super.initState();
    fetchLedgerEntry();
  }

  Future<String?> getAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString("auth_token");
  }

  Future<void> fetchLedgerEntry() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final authKey = await getAuthToken();
      if (authKey == null) {
        throw Exception("Authentication token missing. Please log in.");
      }

      final url = "http://account.galaxyex.xyz/v1/user/api//account/get-ledger/${widget.accountId}";
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
          final List<dynamic> ledgerList = jsonData['data'] ?? [];
          final entry = ledgerList.firstWhere(
                (e) => e['ledgerId'].toString() == widget.ledgerId,
            orElse: () => null,
          );
          setState(() {
            ledgerEntry = entry;
            totals = jsonData['totals'];
            isLoading = false;
          });
        } else {
          setState(() {
            errorMessage = jsonData['meta']?['msg'] ?? "Failed to fetch entry";
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

  String formatDateTime(int milliseconds) {
    final dt = DateTime.fromMillisecondsSinceEpoch(milliseconds);
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final ampm = dt.hour < 12 ? 'AM' : 'PM';
    return "${dt.day.toString().padLeft(2, '0')} "
        "${_monthName(dt.month)} "
        "${dt.year} • "
        "${hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} $ampm";
  }

  String _monthName(int month) {
    const months = [
      "Jan", "Feb", "Mar", "Apr", "May", "Jun",
      "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"
    ];
    return months[(month - 1).clamp(0, 11)];
  }

  Future<void> _confirmAndDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Entry"),
        content: const Text("Are you sure you want to delete this entry? This action cannot be undone."),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text("Delete", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      deleteLedgerEntry();
    }
  }

  Future<void> deleteLedgerEntry() async {
    final authKey = await getAuthToken();
    if (authKey == null) {
      _showSnackBar("Authentication token missing. Please log in.");
      return;
    }
    final url = "http://account.galaxyex.xyz/v1/user/api/setting/remove-ledger/${widget.ledgerId}";
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
        if (jsonData['meta']?['status'] == true) {
          _showSnackBar("Entry deleted successfully");
          await Future.delayed(const Duration(milliseconds: 500));
          Navigator.of(context).pop(true);
        } else {
          _showSnackBar(jsonData['meta']?['msg'] ?? "Failed to delete entry");
        }
      } else {
        _showSnackBar("Failed to delete entry, server error: ${response.statusCode}");
      }
    } catch (e) {
      _showSnackBar("Error deleting entry: $e");
    }
  }

  void _showSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        backgroundColor: Colors.grey[200],
        appBar: AppBar(
          backgroundColor: const Color(0xFF3275A5),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text(
            "Entry Details",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
        ),
        body: isLoading
            ? const Center(child: CircularProgressIndicator())
            : errorMessage != null
            ? Center(child: Text(errorMessage!, style: const TextStyle(fontSize: kFontLarge)))
            : _buildDetails(context),
        bottomNavigationBar: ledgerEntry == null
            ? null
            : SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _confirmAndDelete,
                    icon: const Icon(Icons.delete, color: Colors.red, size: 18),
                    label: const Text(
                      "DELETE",
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.w600,
                        fontSize: kFontMedium,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      // Implement share functionality
                    },
                    icon: const Icon(Icons.share, color: Colors.white, size: 18),
                    label: const Text(
                      "SHARE",
                      style: TextStyle(
                        fontSize: kFontMedium,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF265E85),
                      padding: const EdgeInsets.symmetric(vertical: 12,),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetails(BuildContext context) {
    final entry = ledgerEntry!;
    final accountName = widget.accountName;
    final credit = double.tryParse(entry['creditAmount']?.toString() ?? "0") ?? 0;
    final debit = double.tryParse(entry['debitAmount']?.toString() ?? "0") ?? 0;
    final dateMillis = entry['ledgerDate'] ?? 0;
    final runningBalance = double.tryParse(entry['runningBalance']?.toString() ?? "0") ?? 0;
    final remark = entry['remark'] ?? "";
    final isCredit = credit > 0;
    final isDebit = debit > 0;
    final youGot = isCredit && !isDebit;
    final youGave = isDebit && !isCredit;

    final avatar = widget.accountImageUrl.isEmpty
        ? const CircleAvatar(
      radius: 22,
      backgroundImage: AssetImage('assets/images/default_user.png'),
    )
        : CircleAvatar(
      radius: 22,
      backgroundImage: NetworkImage(widget.accountImageUrl),
    );

    String amountLabel;
    Color amountColor;
    double amountValue;

    if (youGot) {
      amountLabel = "You got";
      amountColor = const Color(0xFF198754);
      amountValue = credit;
    } else {
      amountLabel = "You gave";
      amountColor = const Color(0xffd63384);
      amountValue = debit;
    }

    final accountTotals = totals ?? {};
    final totalCredit = accountTotals['totalCreditAmount'] ?? "";
    final totalDebit = accountTotals['totalDebitAmount'] ?? "";
    final totalBalance = accountTotals['totalBalance'] ?? "";

    return Column(
      children: [
        Container(
            color: const Color(0xFF26698F),
            width: double.infinity,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 20, 10, 10),
                  child: Card(
                    color: Colors.white,
                    elevation: 1.5,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 14, 12, 2),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              avatar,
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      accountName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: kFontLarge,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      formatDateTime(dateMillis),
                                      style: const TextStyle(
                                        color: Colors.grey,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w400,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    "₹ ${amountValue.toStringAsFixed(0)}",
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: kFontLarge,
                                      color: amountColor,
                                    ),
                                  ),
                                  Text(
                                    amountLabel,
                                    style: TextStyle(
                                      color: Colors.grey[700],
                                      fontSize: 13,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 15),
                          const Divider(height: 1),
                          const SizedBox(height: 15),
                          Row(
                            children: [
                              const Text(
                                "Running Balance",
                                style: TextStyle(fontSize: 15),
                              ),
                              const Spacer(),
                              Text(
                                "₹ $totalBalance",
                                style: TextStyle(
                                  color: runningBalance < 0 ? const Color(0xffd63384) : const Color(0xFF198754),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 15),
                          const Divider(height: 1),
                          if (totalCredit != "" && totalDebit != "" && totalBalance != "")
                            const SizedBox(height: 8),
                          Center(
                            child: TextButton.icon(
                              onPressed: () async {
                                // Go to YouWillGivePage or YouWillGetPage with editing context & ledgerId
                                if (youGot) {
                                  final result = await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => YouWillGetPage(
                                        accountId: widget.accountId,
                                        accountName: accountName,
                                        companyId: widget.companyId,
                                        ledgerId: widget.ledgerId,
                                        editCredit: credit,
                                        editRemark: remark,
                                        editDate: DateTime.fromMillisecondsSinceEpoch(dateMillis),
                                      ),
                                    ),
                                  );
                                  if (result == true) {
                                    fetchLedgerEntry();
                                  }
                                } else {
                                  final result = await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => YouWillGivePage(
                                        accountId: widget.accountId,
                                        accountName: accountName,
                                        companyId: widget.companyId,
                                        ledgerId: widget.ledgerId,
                                        editDebit: debit,
                                        editRemark: remark,
                                        editDate: DateTime.fromMillisecondsSinceEpoch(dateMillis),
                                      ),
                                    ),
                                  );
                                  if (result == true) {
                                    fetchLedgerEntry();
                                  }
                                }
                              },
                              icon: const Icon(Icons.edit, color: Color(0xFF265E85), size: 18),
                              label: const Text(
                                "EDIT ENTRY",
                                style: TextStyle(
                                  color: Color(0xFF265E85),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20,)
              ],
            )
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 20, 10, 10),
          child: Column(
            children: [
              const SizedBox(height: 13),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFF198754), width: 1.2),
                      shape: BoxShape.circle,
                    ),
                    padding: const EdgeInsets.all(6),
                    child: const Icon(Icons.verified, color: Color(0xFF198754), size: 18),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    "100% Safe and Secure",
                    style: TextStyle(
                      color: Color(0xFF198754),
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}