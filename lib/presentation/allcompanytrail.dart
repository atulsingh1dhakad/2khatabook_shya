import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'Reportscreen.dart'; // <-- Import if your ReportScreen is in the same folder, adjust path as needed

const Color kPrimaryBlue = Color(0xFF205781);
const Color kGiveRed = Color(0xFFD32F2F);
const Color kGetBlue = Color(0xFF205781);

class AllCompanyTrialScreen extends StatefulWidget {
  const AllCompanyTrialScreen({super.key});

  @override
  State<AllCompanyTrialScreen> createState() => _AllCompanyTrialScreenState();
}

class _AllCompanyTrialScreenState extends State<AllCompanyTrialScreen> {
  bool isLoading = true;
  String? errorMsg;
  List<dynamic> companies = [];
  int totalCredit = 0;
  int totalDebit = 0;
  int totalBalance = 0;

  @override
  void initState() {
    super.initState();
    fetchCompanyTrial();
  }

  Future<String?> getAuthToken() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString("auth_token");
  }

  Future<void> fetchCompanyTrial() async {
    setState(() {
      isLoading = true;
      errorMsg = null;
    });
    const String url = "http://account.galaxyex.xyz/v1/user/api/setting/company-trial";
    try {
      String? authKey = await getAuthToken();

      if (authKey == null) {
        setState(() {
          errorMsg = "No authentication token found. Please log in again.";
          isLoading = false;
        });
        return;
      }

      final response = await http.get(
        Uri.parse(url),
        headers: {
          "Authkey": authKey,
          "Content-Type": "application/json",
        },
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['meta']?['status'] == true) {
          companies = data['data'] ?? [];
          totalCredit = data['overallTotals']?['totalCreditSum'] ?? 0;
          totalDebit = data['overallTotals']?['totalDebitSum'] ?? 0;
          totalBalance = data['overallTotals']?['totalBalanceSum'] ?? 0;
          setState(() {
            isLoading = false;
            errorMsg = null;
          });
        } else {
          setState(() {
            isLoading = false;
            errorMsg = data['meta']?['msg'] ?? 'Failed to fetch data';
            companies = [];
            totalCredit = 0;
            totalDebit = 0;
            totalBalance = 0;
          });
        }
      } else {
        setState(() {
          isLoading = false;
          errorMsg = 'Network error: ${response.statusCode}';
          companies = [];
          totalCredit = 0;
          totalDebit = 0;
          totalBalance = 0;
        });
      }
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMsg = "Error: ${e.toString()}";
        companies = [];
        totalCredit = 0;
        totalDebit = 0;
        totalBalance = 0;
      });
    }
  }

  String getInitials(String name, int index) {
    var parts = name.trim().split(' ');
    if (parts.length == 1) {
      if (index == 0) return 'MC';
      return 'C${index + 1}';
    }
    return (parts[0].isNotEmpty ? parts[0][0] : '') +
        (parts[1].isNotEmpty ? parts[1][0] : '');
  }

  // For list tiles: color based on per-company credit - debit
  Color getListBalanceColor(num credit, num debit) {
    final diff = credit - debit;
    if (diff < 0) return kGiveRed;
    if (diff > 0) return kGetBlue;
    return Colors.grey[700]!;
  }

  // For summary card: color based on overall credit - debit
  Color getCardBalanceColor() {
    final diff = totalCredit - totalDebit;
    if (diff < 0) return kGiveRed;
    if (diff > 0) return kGetBlue;
    return Colors.grey[700]!;
  }

  String formatCompactAmount(num amount) {
    if (amount.abs() >= 10000000) {
      return "${(amount / 10000000).toStringAsFixed(amount % 10000000 == 0 ? 0 : 2)}Cr";
    } else if (amount.abs() >= 100000) {
      return "${(amount / 100000).toStringAsFixed(amount % 100000 == 0 ? 0 : 2)}L";
    } else if (amount.abs() >= 1000) {
      return "${(amount / 1000).toStringAsFixed(amount % 1000 == 0 ? 0 : 1)}K";
    } else {
      return amount.toStringAsFixed(2);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: kPrimaryBlue,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          "All company trial",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
        automaticallyImplyLeading: false,
        toolbarHeight: 70,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMsg != null
          ? Center(child: Text(errorMsg!, style: const TextStyle(color: Colors.red)))
          : Column(
        children: [
          // ---- SUMMARY CARD ----
          Container(
            color: kPrimaryBlue,
            padding: const EdgeInsets.all(8),
            child: Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        InfoCard(
                          title: "You Will Give",
                          amount: "₹${formatCompactAmount(totalDebit)}",
                          amountFontSize: 12,
                          amountColor: kGiveRed,
                        ),
                        InfoCard(
                          title: "You Will Get",
                          amount: "₹${formatCompactAmount(totalCredit)}",
                          amountFontSize: 12,
                          amountColor: kGetBlue,
                        ),
                        InfoCard(
                          title: "Balance",
                          amount: "₹${formatCompactAmount(totalBalance)}",
                          amountFontSize: 12,
                          amountColor: getCardBalanceColor(),
                        ),
                      ],
                    ),
                  ),
                  Divider(
                    color: Colors.grey.shade300,
                    thickness: 1,
                    height: 0,
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5.0),
                    child: GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => ReportScreen()),
                        );
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.file_copy,
                              size: 20, color: Colors.grey),
                          SizedBox(width: 8),
                          Text("Get Report",
                              style: TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: companies.isEmpty
                ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.business, size: 70, color: Colors.grey.withOpacity(0.7)),
                  const SizedBox(height: 12),
                  Text(
                    "No company available",
                    style: TextStyle(fontSize: 18, color: Colors.grey[700]),
                  ),
                ],
              ),
            )
                : ListView.builder(
              itemCount: companies.length,
              itemBuilder: (context, index) {
                final company = companies[index];
                final name = company['companyName'] ?? "Unknown Name";
                final credit = company['totalCredit'] ?? 0;
                final debit = company['totalDebit'] ?? 0;
                final balance = company['totalBalance'] ?? 0;
                return Column(
                  children: [
                    ListTile(
                      leading: CircleAvatar(
                        backgroundColor: kPrimaryBlue,
                        child: Text(
                          getInitials(name, index),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            "₹${formatCompactAmount(balance)}",
                            style: TextStyle(
                              color: getListBalanceColor(credit, debit),
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class InfoCard extends StatelessWidget {
  final String title;
  final String amount;
  final Color amountColor;
  final double amountFontSize;

  const InfoCard({
    required this.title,
    required this.amount,
    required this.amountColor,
    this.amountFontSize = 16,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(title, style: const TextStyle(color: Colors.grey, fontSize: 14)),
        const SizedBox(height: 4),
        Text(
          amount,
          style: TextStyle(
            color: amountColor,
            fontSize: amountFontSize,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}