import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// --- Color Theme --- //
const Color kPrimaryBlue = Color(0xFF205781);
const Color kGiveRed = Color(0xFFD32F2F); // Red for "You Will Give"
const Color kGetGreen = Color(0xFF388E3C); // Green for "You Will Get"
const Color kBalanceGreen = Color(0xFF1B5E20); // Dark green for "Balance"

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
          final overall = data['overallTotals'] ?? {};
          totalCredit = overall['totalCreditSum'] ?? 0;
          totalDebit = overall['totalDebitSum'] ?? 0;
          totalBalance = overall['totalBalanceSum'] ?? 0;
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
          Container(
            color: kPrimaryBlue,
            padding: const EdgeInsets.all(8),
            child: Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    InfoCard(
                      title: "You Will Give",
                      amount: "₹${totalDebit.toStringAsFixed(2)}",
                      amountFontSize: 12,
                      amountColor: kGiveRed,
                    ),
                    InfoCard(
                      title: "You Will Get",
                      amount: "₹${totalCredit.toStringAsFixed(2)}",
                      amountFontSize: 12,
                      amountColor: kGetGreen,
                    ),
                    InfoCard(
                      title: "Balance",
                      amount: "₹${totalBalance.toStringAsFixed(2)}",
                      amountFontSize: 12,
                      amountColor: kBalanceGreen,
                    ),
                  ],
                ),
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
                            "₹${balance.toStringAsFixed(2)}",
                            style: const TextStyle(
                              color: kBalanceGreen,
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