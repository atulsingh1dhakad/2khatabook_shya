import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shya_khatabook/presentation/youwillget.dart';
import 'package:shya_khatabook/presentation/youwillgive.dart';

class CustomerDetails extends StatefulWidget {
  final String accountId;
  final String companyId;

  const CustomerDetails({
    super.key,
    required this.accountId,
    required this.companyId,
  });

  @override
  State<CustomerDetails> createState() => _CustomerDetailsState();
}

class _CustomerDetailsState extends State<CustomerDetails> {
  bool isLoading = true;
  String? errorMessage;
  List<dynamic> ledger = [];
  double totalCredit = 0;
  double totalDebit = 0;
  double totalBalance = 0;
  String accountName = '';
  String accountRemark = '';

  @override
  void initState() {
    super.initState();
    fetchAllData();
  }

  Future<String?> getAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString("auth_token");
  }

  Future<void> fetchAllData() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      await Future.wait([fetchAccountName(), fetchLedger()]);
      setState(() {
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = "Error: $e";
        isLoading = false;
      });
    }
  }

  Future<void> fetchAccountName() async {
    final url = "http://account.galaxyex.xyz/v1/user/api//account/get-account-details/${widget.accountId}";
    final authKey = await getAuthToken();
    if (authKey == null) {
      throw Exception("Authentication token missing. Please log in.");
    }
    final response = await http.get(Uri.parse(url), headers: {
      "Authkey": authKey,
      "Content-Type": "application/json",
    });

    if (response.statusCode == 200) {
      final Map<String, dynamic> jsonData = json.decode(response.body);
      if (jsonData['meta'] != null && jsonData['meta']['status'] == true) {
        setState(() {
          accountName = jsonData['data']?['name'] ?? "";
          accountRemark = jsonData['data']?['remark'] ?? "";
        });
      } else {
        throw Exception(jsonData['meta']?['msg'] ?? "Failed to fetch account name");
      }
    } else {
      throw Exception("Server error fetching account name: ${response.statusCode}");
    }
  }

  Future<void> fetchLedger() async {
    final url = "http://account.galaxyex.xyz/v1/user/api//account/get-ledger/${widget.accountId}";
    final authKey = await getAuthToken();
    if (authKey == null) {
      throw Exception("Authentication token missing. Please log in.");
    }

    final response = await http.get(Uri.parse(url), headers: {
      "Authkey": authKey,
      "Content-Type": "application/json",
    });

    if (response.statusCode == 200) {
      final Map<String, dynamic> jsonData = json.decode(response.body);

      if (jsonData['meta'] != null && jsonData['meta']['status'] == true) {
        setState(() {
          ledger = jsonData['data'] ?? [];
          totalCredit =
              double.tryParse(jsonData['totals']?['totalCreditAmount']?.toString() ?? "0") ?? 0;
          totalDebit =
              double.tryParse(jsonData['totals']?['totalDebitAmount']?.toString() ?? "0") ?? 0;
          totalBalance =
              double.tryParse(jsonData['totals']?['totalBalance']?.toString() ?? "0") ?? 0;
        });
      } else {
        setState(() {
          ledger = [];
          totalCredit = 0;
          totalDebit = 0;
          totalBalance = 0;
        });
        // No need to throw here, just show empty state
      }
    } else {
      setState(() {
        ledger = [];
        totalCredit = 0;
        totalDebit = 0;
        totalBalance = 0;
      });
      // No need to throw here, just show empty state
    }
  }

  String formatDate(int milliseconds) {
    final dt = DateTime.fromMillisecondsSinceEpoch(milliseconds);
    return "${dt.day.toString().padLeft(2, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.year}";
  }

  Widget buildLedgerItem(Map<String, dynamic> entry) {
    final credit = double.tryParse(entry['creditAmount']?.toString() ?? "0") ?? 0;
    final debit = double.tryParse(entry['debitAmount']?.toString() ?? "0") ?? 0;
    final dateMillis = entry['ledgerDate'] ?? 0;
    final remark = entry['remark'] ?? "";

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  formatDate(dateMillis),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                if (remark.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      remark,
                      style: const TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              "Credit: ₹${credit.toStringAsFixed(2)}",
              style: TextStyle(
                  fontSize: 10,
                  color: credit > 0 ? Colors.green[700] : Colors.grey,
                  fontWeight: FontWeight.w600),
              textAlign: TextAlign.right,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: Text(
              "Debit: ₹${debit.toStringAsFixed(2)}",
              style: TextStyle(
                fontSize: 10,
                  color: debit > 0 ? Colors.red[700] : Colors.grey,
                  fontWeight: FontWeight.w600),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(color: Colors.white,),
        title: Text(accountName.isNotEmpty ? accountName : "Loading...", style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF265E85),
      ),
      backgroundColor: const Color(0xFFF4F3EE),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
          ? Center(child: Text(errorMessage!))
          : Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (accountRemark.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      "Remark: $accountRemark",
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                    ),
                  ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      children: [
                        const Text("Total Credit", style: TextStyle(fontSize: 10)),
                        const SizedBox(height: 4),
                        Text(
                          "₹${totalCredit.toStringAsFixed(2)}",
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.green),
                        ),
                      ],
                    ),
                    Column(
                      children: [
                        const Text("Total Debit", style: TextStyle(fontSize: 10)),
                        const SizedBox(height: 4),
                        Text(
                          "₹${totalDebit.toStringAsFixed(2)}",
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.red),
                        ),
                      ],
                    ),
                    Column(
                      children: [
                        const Text("Balance", style: TextStyle(fontSize: 10)),
                        const SizedBox(height: 4),
                        Text(
                          "₹${totalBalance.toStringAsFixed(2)}",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: totalBalance >= 0
                                ? Colors.green[800]
                                : Colors.red[800],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ledger.isEmpty
                ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.inbox, size: 60, color: Colors.grey.withOpacity(0.7)),
                  const SizedBox(height: 12),
                  Text(
                    "No entry available, add now",
                    style: TextStyle(fontSize: 17, color: Colors.grey[700]),
                  ),
                ],
              ),
            )
                : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: ledger.length,
              itemBuilder: (context, index) {
                return buildLedgerItem(ledger[index]);
              },
            ),
          ),
          // Bottom buttons container
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => YouWillGivePage(
                            accountId: widget.accountId,
                            accountName: accountName,
                            companyId: widget.companyId,
                          ),
                        ),
                      ).then((value) => fetchAllData());
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xffc96868),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      "You Give",
                      style: TextStyle(fontSize: 16, color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => YouWillGetPage(
                            accountId: widget.accountId,
                            accountName: accountName,
                            companyId: widget.companyId,
                          ),
                        ),
                      ).then((value) => fetchAllData());
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xff198754),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      "You Get",
                      style: TextStyle(fontSize: 16, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}