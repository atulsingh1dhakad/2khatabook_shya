import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../LIST_LANG.dart';

class ReportScreen extends StatefulWidget {
  final String? companyId;
  const ReportScreen({Key? key, this.companyId}) : super(key: key);

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
          errorMessage = AppStrings.getString("authTokenMissing");
          isLoading = false;
        });
        return;
      }

      final url =
          "http://account.galaxyex.xyz/v1/user/api/user/get-report${widget.companyId != null ? '?companyId=${widget.companyId}' : ''}";
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
            errorMessage = jsonData['meta']?['msg'] ?? AppStrings.getString("failedToFetchReport");
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

  String formatDateTime(int millis) {
    if (millis == 0) return "-";
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

  // Helper: Capitalize each word
  String toTitleCase(String text) {
    if (text.isEmpty) return text;
    return text
        .split(' ')
        .map((word) => word.isEmpty
        ? word
        : word[0].toUpperCase() + word.substring(1).toLowerCase())
        .join(' ');
  }

  // Helper: Format amounts with K,L,Cr
  String formatCompactAmount(num? amount) {
    if (amount == null) return "-";
    if (amount.abs() >= 10000000) {
      return "${(amount / 10000000).toStringAsFixed(amount % 10000000 == 0 ? 0 : 2)}${AppStrings.getString("CR")}";
    } else if (amount.abs() >= 100000) {
      return "${(amount / 100000).toStringAsFixed(amount % 100000 == 0 ? 0 : 2)}${AppStrings.getString("L")}";
    } else if (amount.abs() >= 1000) {
      return "${(amount / 1000).toStringAsFixed(amount % 1000 == 0 ? 0 : 1)}${AppStrings.getString("K")}";
    } else {
      return amount.toStringAsFixed(2);
    }
  }

  /// Compute running balance as per CustomerDetails logic, for the report.
  List<double?> runningBalances() {
    double sum = 0;
    List<double?> balances = List.filled(ledgerList.length, null);
    for (int i = ledgerList.length - 1; i >= 0; i--) {
      final credit = double.tryParse(ledgerList[i]['creditAmount']?.toString() ?? "0") ?? 0;
      final debit = double.tryParse(ledgerList[i]['debitAmount']?.toString() ?? "0") ?? 0;
      sum += credit - debit;
      balances[i] = sum;
    }
    return balances;
  }

  @override
  Widget build(BuildContext context) {
    final giveColor = Colors.red[700]!;
    final getColor = const Color(0xFF205781);

    double totalDebit = double.tryParse(totals['totalDebitAmount']?.toString() ?? "0") ?? 0;
    double totalCredit = double.tryParse(totals['totalCreditAmount']?.toString() ?? "0") ?? 0;
    double balance = double.tryParse(totals['totalBalance']?.toString() ?? "0") ?? 0;
    final balanceColor = balance < 0 ? giveColor : getColor;

    final runningBalancesList = runningBalances();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          AppStrings.getString('report'),
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF22587a),
        elevation: 0,
        leading: const BackButton(color: Colors.white),
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
                ? Center(child: Text(AppStrings.getString("noRecords")))
                : ListView.separated(
              separatorBuilder: (_, __) =>
              const Divider(height: 0),
              itemCount: ledgerList.length,
              itemBuilder: (context, index) {
                final entry = ledgerList[index];
                final username = toTitleCase(entry['username'] ?? '');
                final isCredit =
                    double.tryParse(entry['creditAmount'] ?? "0.00")! > 0;
                final isDebit =
                    double.tryParse(entry['debitAmount'] ?? "0.00")! > 0;
                final amount = isCredit
                    ? entry['creditAmount']
                    : entry['debitAmount'];
                final amountNum =
                    double.tryParse(amount?.toString() ?? "0") ?? 0;

                final amountColor = isCredit ? getColor : giveColor;

                final balNum = runningBalancesList[index];
                final runningBalanceProper = balNum != null && balNum.isFinite;

                final balText = runningBalanceProper
                    ? "₹${formatCompactAmount(balNum!)}"
                    : "-";
                final balTextColor = !runningBalanceProper
                    ? Colors.grey
                    : (balNum! < 0 ? giveColor : getColor);

                return Container(
                  color: index.isOdd
                      ? const Color(0xFFFFFCFC)
                      : Colors.white,
                  child: ListTile(
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 2),
                    title: Text(
                      username,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15),
                    ),
                    subtitle: Column(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,
                      children: [
                        Text(
                          formatDateTime(
                              entry['ledgerDate'] ?? 0),
                          style: const TextStyle(
                              fontSize: 13,
                              color: Colors.black54),
                        ),
                        if ((entry['remark'] ?? '')
                            .toString()
                            .isNotEmpty)
                          Text(
                            toTitleCase(entry['remark']),
                            style: const TextStyle(
                                fontSize: 13,
                                color: Colors.black87),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        Text(
                          balText,
                          style: TextStyle(
                            fontSize: 13,
                            color: balTextColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (!runningBalanceProper)
                          Text(
                            AppStrings.getString("runningBalanceNotProper"),
                            style: const TextStyle(
                                fontSize: 12,
                                color: Colors.orange,
                                fontWeight: FontWeight.w500),
                          ),
                      ],
                    ),
                    trailing: Text(
                      "₹${formatCompactAmount(amountNum)}",
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
    double? debitV = double.tryParse(debit?.toString() ?? "");
    double? creditV = double.tryParse(credit?.toString() ?? "");
    double? balanceV = double.tryParse(balance?.toString() ?? "");
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
                  Text(
                    AppStrings.getString("youWillGive"),
                    style: const TextStyle(
                        fontSize: 13, color: Colors.black87),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "₹${formatCompactAmount(debitV ?? 0)}",
                    style: TextStyle(
                        color: giveColor,
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
                  Text(
                    AppStrings.getString("youWillGet"),
                    style: const TextStyle(
                        fontSize: 13, color: Colors.black87),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "₹${formatCompactAmount(creditV ?? 0)}",
                    style: TextStyle(
                        color: getColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 13),
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
                  Text(
                    AppStrings.getString("balance"),
                    style: const TextStyle(
                        fontSize: 13, color: Colors.black87),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "₹${formatCompactAmount(balanceV ?? 0)}",
                    style: TextStyle(
                        color: balanceColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 13),
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
}