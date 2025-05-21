import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shya_khatabook/presentation/youwillget.dart';
import 'package:shya_khatabook/presentation/youwillgive.dart';

class CustomerDetails extends StatefulWidget {
  final String accountId;
  final String accountName;

  const CustomerDetails({
    super.key,
    required this.accountId,
    required this.accountName,
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

  @override
  void initState() {
    super.initState();
    fetchLedger();
  }

  Future<String?> getAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString("auth_token");
  }

  Future<void> fetchLedger() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    final url =
        "http://account.galaxyex.xyz/v1/user/api//account/get-ledger/${widget.accountId}";

    try {
      final authKey = await getAuthToken();
      if (authKey == null) {
        setState(() {
          errorMessage = "Authentication token missing. Please log in.";
          isLoading = false;
        });
        return;
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
                double.tryParse(jsonData['totals']?['totalCreditAmount'] ?? "0") ??
                    0;
            totalDebit =
                double.tryParse(jsonData['totals']?['totalDebitAmount'] ?? "0") ??
                    0;
            totalBalance =
                double.tryParse(jsonData['totals']?['totalBalance'] ?? "0") ?? 0;
            isLoading = false;
          });
        } else {
          setState(() {
            errorMessage = jsonData['meta']?['msg'] ?? "Failed to fetch ledger data";
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

  String formatDate(int milliseconds) {
    final dt = DateTime.fromMillisecondsSinceEpoch(milliseconds);
    return "${dt.day.toString().padLeft(2, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.year}";
  }

  Widget buildLedgerItem(Map<String, dynamic> entry) {
    final credit = double.tryParse(entry['creditAmount'] ?? "0") ?? 0;
    final debit = double.tryParse(entry['debitAmount'] ?? "0") ?? 0;
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
        title: Text(widget.accountName,style: TextStyle(color: Colors.white),),
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
            padding:
            const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  children: [
                    const Text("Total Credit", style: TextStyle(fontSize: 16)),
                    const SizedBox(height: 4),
                    Text(
                      "₹${totalCredit.toStringAsFixed(2)}",
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.green),
                    ),
                  ],
                ),
                Column(
                  children: [
                    const Text("Total Debit", style: TextStyle(fontSize: 16)),
                    const SizedBox(height: 4),
                    Text(
                      "₹${totalDebit.toStringAsFixed(2)}",
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.red),
                    ),
                  ],
                ),
                Column(
                  children: [
                    const Text("Balance", style: TextStyle(fontSize: 16)),
                    const SizedBox(height: 4),
                    Text(
                      "₹${totalBalance.toStringAsFixed(2)}",
                      style: TextStyle(
                        fontSize: 18,
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
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
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
                      // TODO: Add action for "You Give"
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xffc96868),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: GestureDetector(
                      onTap: (){
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => YouWillGivePage()),
                        );
                      },
                      child: const Text(
                        "You Give",
                        style: TextStyle(fontSize: 16,color: Colors.white),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      // TODO: Add action for "You Get"
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xff198754),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: GestureDetector(
                      onTap: (){
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => YouWillGetPage()),
                        );
                      },
                      child: const Text(
                        "You Get",
                        style: TextStyle(fontSize: 16,color:Colors.white),
                      ),
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
