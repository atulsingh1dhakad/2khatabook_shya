import 'dart:convert';
import 'package:Calculator/presentation/sidebarscreen.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../ledgerdetails.dart';
import 'youwillgive.dart';
import 'youwillget.dart';

const double kFontVerySmall = 10;
const double kFontSmall = 13;
const double kFontMedium = 16;
const double kFontLarge = 14;
const double kFontXLarge = 12;

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

class _CustomerDetailsState extends State<CustomerDetails> with RouteAware {
  bool isLoading = true;
  bool isDeleting = false;
  String? errorMessage;
  List<dynamic> ledger = [];
  double totalCredit = 0;
  double totalDebit = 0;
  double totalBalance = 0;
  String accountName = '';
  String accountRemark = '';
  bool dataChanged = false;

  RouteObserver<ModalRoute<void>>? _routeObserver;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _routeObserver = ModalRoute.of(context)?.navigator?.widget is Navigator
        ? (ModalRoute.of(context)?.navigator?.widget as Navigator).observers
        .whereType<RouteObserver<ModalRoute<void>>>()
        .firstOrNull
        : null;
    _routeObserver?.subscribe(this, ModalRoute.of(context)!);
  }

  @override
  void dispose() {
    _routeObserver?.unsubscribe(this);
    Navigator.pop(context, dataChanged);
    super.dispose();
  }

  @override
  void didPopNext() {
    fetchAllData();
    super.didPopNext();
  }

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
    final url =
        "http://account.galaxyex.xyz/v1/user/api//account/get-account-details/${widget.accountId}";
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
        throw Exception(
            jsonData['meta']?['msg'] ?? "Failed to fetch account name");
      }
    } else {
      throw Exception(
          "Server error fetching account name: ${response.statusCode}");
    }
  }

  Future<void> fetchLedger() async {
    final url =
        "http://account.galaxyex.xyz/v1/user/api//account/get-ledger/${widget.accountId}";
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
          totalCredit = double.tryParse(
              jsonData['totals']?['totalCreditAmount']?.toString() ?? "0") ??
              0;
          totalDebit = double.tryParse(
              jsonData['totals']?['totalDebitAmount']?.toString() ?? "0") ??
              0;
          totalBalance = double.tryParse(
              jsonData['totals']?['totalBalance']?.toString() ?? "0") ??
              0;
        });
      } else {
        setState(() {
          ledger = [];
          totalCredit = 0;
          totalDebit = 0;
          totalBalance = 0;
        });
      }
    } else {
      setState(() {
        ledger = [];
        totalCredit = 0;
        totalDebit = 0;
        totalBalance = 0;
      });
    }
  }

  Future<void> deleteLedgerEntry(String ledgerId) async {
    setState(() {
      isDeleting = true;
    });
    final authKey = await getAuthToken();
    if (authKey == null) {
      _showSnackBar("Authentication token missing. Please log in.");
      setState(() {
        isDeleting = false;
      });
      return;
    }

    final url =
        "http://account.galaxyex.xyz/v1/user/api/setting/remove-ledger/$ledgerId";
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
          await fetchLedger();
          dataChanged = true;
        } else {
          _showSnackBar(jsonData['meta']?['msg'] ?? "Failed to delete entry");
        }
      } else {
        _showSnackBar(
            "Failed to delete entry, server error: ${response.statusCode}");
      }
    } catch (e) {
      _showSnackBar("Error deleting entry: $e");
    }
    setState(() {
      isDeleting = false;
    });
  }

  void _showSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  String formatDateTime(int milliseconds) {
    final dt = DateTime.fromMillisecondsSinceEpoch(milliseconds);
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final ampm = dt.hour < 12 ? 'AM' : 'PM';
    return "${dt.day.toString().padLeft(2, '0')} "
        "${_monthName(dt.month)} "
        "${dt.year} "
        "${hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} $ampm";
  }

  String _monthName(int month) {
    const months = [
      "Jan",
      "Feb",
      "Mar",
      "Apr",
      "May",
      "Jun",
      "Jul",
      "Aug",
      "Sep",
      "Oct",
      "Nov",
      "Dec"
    ];
    return months[(month - 1).clamp(0, 11)];
  }

  /// Compute running balances for the ledger in reverse order (bottom-up)
  List<double> _reversedRunningBalances() {
    double sum = 0;
    List<double> balances = List.filled(ledger.length, 0);
    // Traverse from end to start
    for (int i = ledger.length - 1; i >= 0; i--) {
      final credit = double.tryParse(ledger[i]['creditAmount']?.toString() ?? "0") ?? 0;
      final debit = double.tryParse(ledger[i]['debitAmount']?.toString() ?? "0") ?? 0;
      sum += credit - debit;
      balances[i] = sum;
    }
    return balances;
  }

  Widget buildLedgerItem(Map<String, dynamic> entry, double runningBalance) {
    final credit =
        double.tryParse(entry['creditAmount']?.toString() ?? "0") ?? 0;
    final debit = double.tryParse(entry['debitAmount']?.toString() ?? "0") ?? 0;
    final dateMillis = entry['ledgerDate'] ?? 0;
    final remark = entry['remark'] ?? "";
    final ledgerId = entry['ledgerId']?.toString() ?? "";

    // Show balance with minus sign if negative
    final String balanceText =
    (runningBalance < 0 ? "-₹${runningBalance.abs().toStringAsFixed(2)}" : "₹${runningBalance.toStringAsFixed(2)}");

    return GestureDetector(
      onTap: () async {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => LedgerDetails(
              ledgerId: ledgerId,
              accountName: accountName,
              companyId: widget.companyId,
              accountId: widget.accountId,
            ),
          ),
        );
        if (result == true) {
          await fetchAllData();
          dataChanged = true;
        }
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left: Date + Balance cream + Remark
              Expanded(
                flex: 6,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      formatDateTime(dateMillis),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: kFontSmall,
                        color: Colors.black,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 2.0, bottom: 2.0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            vertical: 2, horizontal: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xCEDF9F4D).withOpacity(0.18), // Cream background
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          balanceText,
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                    if (remark.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 1),
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
              // Entries, You Gave, You Get
              Expanded(
                flex: 7,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // You Gave (show pinkish background always)
                    Container(
                      width: 80,
                      alignment: Alignment.centerLeft,
                      child: Container(
                        height: 50,
                        decoration: BoxDecoration(
                          color: Color(0xffd63384).withOpacity(0.05),
                        ),
                        padding: const EdgeInsets.symmetric(
                            vertical: 2, horizontal: 10),
                        alignment: Alignment.center,
                        child: debit == 0
                            ? const Text(
                          "",
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 14.5,
                            color: Colors.red,
                          ),
                        )
                            : Text(
                          "₹${debit.toStringAsFixed(2)}",
                          style: const TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 14.5,
                            color: Colors.red,
                          ),
                        ),
                      ),
                    ),
                    // You Get
                    Container(
                      width: 80,
                      alignment: Alignment.centerRight,
                      child: credit == 0
                          ? const SizedBox.shrink()
                          : Text(
                        "₹${credit.toStringAsFixed(2)}",
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 14.5,
                          color: Color(0xFF198754),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleEntryChange(Future<dynamic> future) async {
    final value = await future;
    if (value == true) {
      await fetchAllData();
      dataChanged = true;
    }
  }

  Future<bool> _onWillPop() async {
    Navigator.pop(context, dataChanged);
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final double displayCredit = totalCredit;
    final double displayDebit = totalDebit;
    final double balance = displayCredit - displayDebit;

    String label;
    Color amountTextColor;
    double displayAmount;

    if (balance < 0) {
      label = "You Will Give";
      amountTextColor = const Color(0xffc96868);
      displayAmount = -balance;
    } else if (balance > 0) {
      label = "You Will Get";
      amountTextColor = const Color(0xFF198754);
      displayAmount = balance;
    } else {
      label = "Settled Up";
      amountTextColor = Colors.grey;
      displayAmount = 0.0;
    }

    // Compute reversed running balances (so that the last entry is at the bottom and matches the bottom row)
    final reversedRunningBalances = _reversedRunningBalances();

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(120),
          child: AppBar(
            automaticallyImplyLeading: false,
            backgroundColor: const Color(0xFF265E85),
            elevation: 0,
            flexibleSpace: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Row: Back, Title, Settings
                  Padding(
                    padding: const EdgeInsets.only(
                        left: 0, right: 0, top: 0, bottom: 0),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back, color: Colors.white),
                          onPressed: () => Navigator.pop(context, dataChanged),
                        ),
                        Expanded(
                          child: Text(
                            accountName.isNotEmpty
                                ? accountName
                                : "Loading...",
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.settings, color: Colors.white),
                          onPressed: () {
                            Navigator.push(context, MaterialPageRoute(builder: (context) => SettingsScreen(),));
                          },
                        ),
                      ],
                    ),
                  ),
                  // Summary Card (falls inside AppBar)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.07),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                vertical: 16, horizontal: 14),
                            child: Text(
                              label,
                              style: const TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.w500,
                                fontSize: kFontXLarge,
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(right: 16.0),
                          child: Text(
                            "₹${displayAmount.toStringAsFixed(2)}",
                            style: TextStyle(
                              color: amountTextColor,
                              fontWeight: FontWeight.w500,
                              fontSize: kFontLarge,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        backgroundColor: const Color(0xFFF4F3EE),
        body: isLoading
            ? const Center(child: CircularProgressIndicator())
            : errorMessage != null
            ? Center(
            child: Text(errorMessage!,
                style: const TextStyle(fontSize: kFontLarge)))
            : Column(
          children: [
            // Labels Row (above the list, shown only once)
            Padding(
              padding: const EdgeInsets.only(
                  left: 18, right: 12, top: 8, bottom: 2),
              child: Row(
                children: [
                  Expanded(
                    flex: 6,
                    child: Text(
                      "Date/Remark",
                      style: TextStyle(
                        fontSize: kFontVerySmall,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 7,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Container(
                          width: 38,
                          alignment: Alignment.centerRight,
                          child: Text(
                            "",
                            style: TextStyle(
                              fontSize: kFontVerySmall,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        Container(
                          width: 70,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            "You Gave",
                            style: TextStyle(
                              fontSize: kFontVerySmall,
                              color: const Color(0xffc96868),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        Container(
                          width: 60,
                          alignment: Alignment.centerRight,
                          child: Text(
                            "You Get",
                            style: TextStyle(
                              fontSize: kFontVerySmall,
                              color: const Color(0xFF198754),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Ledger list
            Expanded(
              child: Container(
                color: Colors.transparent,
                child: ledger.isEmpty
                    ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.inbox,
                          size: 60,
                          color:
                          Colors.grey.withOpacity(0.7)),
                      const SizedBox(height: 12),
                      Text(
                        "No entry available, add now",
                        style: TextStyle(
                            fontSize: kFontLarge,
                            color: Colors.grey[700]),
                      ),
                    ],
                  ),
                )
                    : ListView.builder(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 0),
                  itemCount: ledger.length,
                  itemBuilder: (context, index) {
                    // Use reversed running balance for visible row
                    final runningBalance = reversedRunningBalances[index];
                    return buildLedgerItem(
                      ledger[index],
                      runningBalance,
                    );
                  },
                ),
              ),
            ),
            // Bottom buttons container
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          _handleEntryChange(
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => YouWillGivePage(
                                  accountId: widget.accountId,
                                  accountName: accountName,
                                  companyId: widget.companyId,
                                ),
                              ),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xffc96868),
                          padding: const EdgeInsets.symmetric(
                              vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(7),
                          ),
                        ),
                        child: const Text(
                          "You Give",
                          style: TextStyle(
                              fontSize: kFontLarge,
                              color: Colors.white),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          _handleEntryChange(
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => YouWillGetPage(
                                  accountId: widget.accountId,
                                  accountName: accountName,
                                  companyId: widget.companyId,
                                ),
                              ),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF198754),
                          padding: const EdgeInsets.symmetric(
                              vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(7),
                          ),
                        ),
                        child: const Text(
                          "You Get",
                          style: TextStyle(
                              fontSize: kFontLarge,
                              color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}