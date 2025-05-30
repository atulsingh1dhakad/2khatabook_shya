import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

class ReportScreen extends StatefulWidget {
  const ReportScreen({Key? key}) : super(key: key);

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  bool isLoading = true;
  String? errorMessage;
  List<Map<String, dynamic>> ledgerList = [];
  Map<String, dynamic> totals = {};

  @override
  void initState() {
    super.initState();
    fetchReport();
  }

  Future<void> fetchReport() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final authKey = prefs.getString("auth_token");
      if (authKey == null) {
        setState(() {
          errorMessage = "Authentication token missing. Please log in.";
          isLoading = false;
        });
        return;
      }

      final url = "http://account.galaxyex.xyz/v1/user/api/user/get-report";
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
          final List<dynamic> data = jsonData['data'] ?? [];
          setState(() {
            ledgerList = data.cast<Map<String, dynamic>>();
            totals = jsonData['totals'] ?? {};
            isLoading = false;
          });
        } else {
          setState(() {
            errorMessage = jsonData['meta']?['msg'] ?? "Failed to fetch report";
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

  String formatDateTime(int millis) {
    final dt = DateTime.fromMillisecondsSinceEpoch(millis);
    String hour = (dt.hour % 12 == 0 ? 12 : dt.hour % 12).toString().padLeft(2, '0');
    String ampm = dt.hour < 12 ? 'AM' : 'PM';
    return "${dt.day.toString().padLeft(2, '0')} ${_monthName(dt.month)} ${dt.year} $hour:${dt.minute.toString().padLeft(2, '0')} $ampm";
  }

  String _monthName(int month) {
    const months = [
      "Jan", "Feb", "Mar", "Apr", "May", "Jun",
      "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"
    ];
    return months[(month - 1).clamp(0, 11)];
  }

  @override
  Widget build(BuildContext context) {
    final giveColor = Colors.red[700]!;
    final getColor = Colors.blue[800]!;
    final balanceColor = Colors.green[700]!;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Report',style: TextStyle(color: Colors.white),),
        backgroundColor: const Color(0xFF22587a),
        elevation: 0,
        leading: const BackButton(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white),
            onPressed: () {},
          ),
        ],
      ),
      backgroundColor: const Color(0xFFF7F8FA),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
          ? Center(child: Text(errorMessage!))
          : Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 12, 10, 6),
            child: _singleTopCard(
              debit: totals['totalDebitAmount'],
              credit: totals['totalCreditAmount'],
              balance: totals['totalBalance'],
              giveColor: giveColor,
              getColor: getColor,
              balanceColor: balanceColor,
            ),
          ),
          Expanded(
            child: ledgerList.isEmpty
                ? const Center(child: Text("No records"))
                : ListView.separated(
              separatorBuilder: (_, __) => const Divider(height: 0),
              itemCount: ledgerList.length,
              itemBuilder: (context, index) {
                final entry = ledgerList[index];
                final isCredit = double.tryParse(entry['creditAmount'] ?? "0.00")! > 0;
                final isDebit = double.tryParse(entry['debitAmount'] ?? "0.00")! > 0;
                final amount = isCredit
                    ? entry['creditAmount']
                    : entry['debitAmount'];
                final amountColor = isCredit ? getColor : giveColor;
                final bal = entry['balance'] ?? "";
                final balNum = double.tryParse(bal) ?? 0.0;
                return Container(
                  color: index.isOdd
                      ? const Color(0xFFFFFCFC)
                      : Colors.white,
                  child: ListTile(
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                    title: Text(
                      entry['username'] ?? '',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          formatDateTime(entry['ledgerDate'] ?? 0),
                          style: const TextStyle(fontSize: 13, color: Colors.black54),
                        ),
                        if ((entry['remark'] ?? '').toString().isNotEmpty)
                          Text(
                            entry['remark'],
                            style: const TextStyle(fontSize: 13, color: Colors.black87),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        Text(
                          '₹${_fmt(bal)}',
                          style: TextStyle(
                            fontSize: 13,
                            color: balNum < 0 ? giveColor : balanceColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    trailing: Text(
                      "₹${_fmt(amount)}",
                      style: TextStyle(
                          color: amountColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 16),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _singleTopCard({
    required dynamic debit,
    required dynamic credit,
    required dynamic balance,
    required Color giveColor,
    required Color getColor,
    required Color balanceColor,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
              color: Colors.black12.withOpacity(0.07),
              blurRadius: 7,
              spreadRadius: 1,
              offset: const Offset(0, 2))
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                children: [
                  const Text("You Will Give", style: TextStyle(fontSize: 13, color: Colors.black87)),
                  const SizedBox(height: 2),
                  Text(
                    "₹${_fmt(debit)}",
                    style: TextStyle(
                        color: giveColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 13 // Small font for amount
                    ),
                  ),
                ],
              ),
            ),
          ),
          _verticalDivider(),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                children: [
                  const Text("You Will Get", style: TextStyle(fontSize: 13, color: Colors.black87)),
                  const SizedBox(height: 2),
                  Text(
                    "₹${_fmt(credit)}",
                    style: TextStyle(
                        color: getColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 13
                    ),
                  ),
                ],
              ),
            ),
          ),
          _verticalDivider(),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                children: [
                  const Text("Balance", style: TextStyle(fontSize: 13, color: Colors.black87)),
                  const SizedBox(height: 2),
                  Text(
                    "₹${_fmt(balance)}",
                    style: TextStyle(
                        color: balanceColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 13
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _verticalDivider() {
    return Container(
      width: 1,
      height: 36,
      color: const Color(0xFFE1E1E1),
    );
  }

  String _fmt(dynamic val) {
    if (val == null) return "0.00";
    if (val is num) return val.toStringAsFixed(2);
    if (val is String) {
      if (val.contains('.')) {
        final parts = val.split('.');
        if (parts[1].length == 1) return "${parts[0]}.${parts[1]}0";
        if (parts[1].length == 0) return "${parts[0]}.00";
        if (parts[1].length > 2) return "${parts[0]}.${parts[1].substring(0, 2)}";
      }
      return val;
    }
    return val.toString();
  }
}
/*accountId*/