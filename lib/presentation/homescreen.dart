import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'Addcompanyscreen.dart';
import 'Addcustomerscreen.dart';
import 'sidebarscreen.dart';
import 'costumer details.dart';

const double kFontSmall = 12;
const double kFontMedium = 16;
const double kFontLarge = 15;
const double kFontXLarge = 18;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  String? selectedCompanyId;
  String? selectedCompanyName;
  List<dynamic> companies = [];
  List<dynamic> accounts = [];
  bool isLoadingCompanies = true;
  bool isLoadingAccounts = false;
  String? errorMsg;
  double totalCredit = 0;
  double totalDebit = 0;
  double balance = 0;
  String searchQuery = "";

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    fetchCompanies();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Reads the lastUpdate value from backend (`acc['lastUpdate']`) and formats it.
  /// Falls back to "Never" if not available or invalid.
  String getFormattedLastUpdate(Map<String, dynamic> acc) {
    final lastUpdate = acc['lastUpdate'];
    if (lastUpdate == null) return "Never";
    try {
      DateTime dt;
      if (lastUpdate is int) {
        dt = DateTime.fromMillisecondsSinceEpoch(lastUpdate);
      } else if (lastUpdate is String) {
        dt = DateTime.parse(lastUpdate);
      } else {
        return "Never";
      }
      final date = "${dt.day.toString().padLeft(2, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.year}";
      final time = "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
      return "$date $time";
    } catch (_) {
      return "Never";
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && selectedCompanyId != null) {
      fetchAccounts(selectedCompanyId!);
    }
  }

  Future<String?> getAuthToken() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString("auth_token");
  }

  Future<void> fetchCompanies() async {
    const String url = "http://account.galaxyex.xyz/v1/user/api//account/get-company";
    try {
      String? authKey = await getAuthToken();

      if (authKey == null) {
        setState(() {
          errorMsg = "No authentication token found. Please log in again.";
          isLoadingCompanies = false;
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
        if (data['meta']['status']) {
          List<dynamic> fetchedCompanies = data['data'];
          fetchedCompanies.sort((a, b) => (a['companyName'] ?? '').toString().toLowerCase().compareTo((b['companyName'] ?? '').toString().toLowerCase()));

          String? defaultCompanyId;
          String? defaultCompanyName;

          if (fetchedCompanies.isNotEmpty) {
            final defaultCompany = fetchedCompanies.firstWhere(
                  (c) => c['companyName'] == "My Company 1",
              orElse: () => fetchedCompanies[0],
            );
            defaultCompanyId = defaultCompany['companyId'];
            defaultCompanyName = defaultCompany['companyName'];
          }

          setState(() {
            companies = fetchedCompanies;
            selectedCompanyId = defaultCompanyId;
            selectedCompanyName = defaultCompanyName;
            isLoadingCompanies = false;
            errorMsg = null;
          });

          if (defaultCompanyId != null) {
            fetchAccounts(defaultCompanyId);
          }
        } else {
          setState(() {
            companies = [];
            selectedCompanyId = null;
            selectedCompanyName = null;
            isLoadingCompanies = false;
            errorMsg = null;
          });
        }
      } else {
        setState(() {
          companies = [];
          selectedCompanyId = null;
          selectedCompanyName = null;
          isLoadingCompanies = false;
          errorMsg = null;
        });
      }
    } catch (e) {
      setState(() {
        companies = [];
        selectedCompanyId = null;
        selectedCompanyName = null;
        isLoadingCompanies = false;
        errorMsg = null;
      });
    }
  }

  Future<void> fetchAccounts(String companyId) async {
    setState(() {
      isLoadingAccounts = true;
      accounts = [];
      totalCredit = 0;
      totalDebit = 0;
      balance = 0;
    });
    final String url = "http://account.galaxyex.xyz/v1/user/api//account/get-account/$companyId";
    try {
      String? authKey = await getAuthToken();

      if (authKey == null) {
        setState(() {
          accounts = [];
          totalCredit = 0;
          totalDebit = 0;
          balance = 0;
          isLoadingAccounts = false;
          errorMsg = null;
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
        if (data['meta']['status']) {
          setState(() {
            accounts = data['data'] ?? [];
            totalCredit = double.tryParse(data['overallTotals']?['totalCreditSum']?.toString() ?? "0") ?? 0;
            totalDebit = double.tryParse(data['overallTotals']?['totalDebitSum']?.toString() ?? "0") ?? 0;
            balance = double.tryParse(data['overallTotals']?['totalBalanceSum']?.toString() ?? "0") ?? (totalCredit - totalDebit);
            isLoadingAccounts = false;
            errorMsg = null;
          });
        } else {
          setState(() {
            accounts = [];
            totalCredit = 0;
            totalDebit = 0;
            balance = 0;
            isLoadingAccounts = false;
            errorMsg = null;
          });
        }
      } else {
        setState(() {
          accounts = [];
          totalCredit = 0;
          totalDebit = 0;
          balance = 0;
          isLoadingAccounts = false;
          errorMsg = null;
        });
      }
    } catch (e) {
      setState(() {
        accounts = [];
        totalCredit = 0;
        totalDebit = 0;
        balance = 0;
        isLoadingAccounts = false;
        errorMsg = null;
      });
    }
  }

  void onCompanyChanged(String? newCompanyId, String? newCompanyName) {
    setState(() {
      selectedCompanyId = newCompanyId;
      selectedCompanyName = newCompanyName;
    });
    if (newCompanyId != null) {
      fetchAccounts(newCompanyId);
    }
    Navigator.of(context).pop(); // Close the bottom sheet
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

  void _showCompanySelectorBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      backgroundColor: Colors.white,
      builder: (context) {
        return Wrap(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.3,
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          ...companies.asMap().entries.map((entry) {
                            final index = entry.key;
                            final company = entry.value;
                            final bool isSelected =
                                selectedCompanyId == company['companyId'];
                            return GestureDetector(
                              onTap: () => onCompanyChanged(
                                company['companyId'],
                                company['companyName'],
                              ),
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.symmetric(
                                    vertical: 6, horizontal: 5),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? const Color(0xFF205781)
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isSelected
                                        ? const Color(0xFF205781)
                                        : Colors.grey.shade300,
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 16,
                                      backgroundColor: const Color(0xFF205781),
                                      child: Text(
                                        getInitials(
                                          company['companyName'],
                                          index,
                                        ),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: kFontMedium,
                                          letterSpacing: 1.2,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            company['companyName'],
                                            style: TextStyle(
                                              color: isSelected
                                                  ? Colors.white
                                                  : const Color(0xFF205781),
                                              fontWeight: FontWeight.w600,
                                              fontSize: kFontLarge,
                                            ),
                                          ),
                                          const SizedBox(height: 1),
                                          Text(
                                            "4 Customers",
                                            style: TextStyle(
                                              color: isSelected
                                                  ? Colors.white.withOpacity(0.8)
                                                  : const Color(0xFF205781),
                                              fontWeight: FontWeight.w400,
                                              fontSize: kFontSmall,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => AddCompanyPage()),
                      );
                    },
                    icon: const Icon(Icons.add, size: 20, color: Colors.white),
                    label: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 6.0),
                      child: Text(
                        "Add New Company",
                        style: TextStyle(
                            fontSize: kFontLarge,
                            fontWeight: FontWeight.w500,
                            color: Colors.white),
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF205781),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 1,
                      minimumSize: const Size.fromHeight(60),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredAccounts = searchQuery.isEmpty
        ? accounts
        : accounts.where((acc) {
      final name = (acc['name'] ?? '').toString().toLowerCase();
      return name.contains(searchQuery.toLowerCase());
    }).toList();

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: const Color(0xFF205781),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            isLoadingCompanies
                ? const SizedBox(
              width: 200,
              child: LinearProgressIndicator(
                backgroundColor: Colors.white,
                color: Color(0xFF205781),
              ),
            )
                : Expanded(
              child: GestureDetector(
                onTap: () {
                  _showCompanySelectorBottomSheet(context);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      vertical: 8, horizontal: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF205781),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.library_books_rounded,
                          color: Colors.white),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          selectedCompanyName ?? "Select Company",
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: kFontXLarge,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const Icon(Icons.arrow_downward,
                          color: Colors.white, size: 20),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
                child: const Icon(Icons.settings_suggest_outlined,
                    color: Colors.white),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const settingscreen()),
                  );
                })
          ],
        ),
        toolbarHeight: 70,
      ),
      body: Column(
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                color: const Color(0xFF205781),
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
                          children: [
                            Expanded(
                              child: InfoCard(
                                title: "You Will Give",
                                amount: "₹${totalDebit.toStringAsFixed(2)}",
                                amountFontSize: kFontLarge,
                                amountColor: Colors.red,
                              ),
                            ),
                            SizedBox(
                              width: 10,
                            ),
                            Column(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: List.generate(
                                15,
                                    (_) => Container(
                                  width: 1.5,
                                  height: 3,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 10,
                            ),
                            Expanded(
                              child: InfoCard(
                                title: "You Will Get",
                                amount: "₹${totalCredit.toStringAsFixed(2)}",
                                amountFontSize: kFontLarge,
                              ),
                            ),
                            SizedBox(
                              width: 10,
                            ),
                            Column(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: List.generate(
                                15,
                                    (_) => Container(
                                  width: 1.5,
                                  height: 3,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 10,
                            ),
                            Expanded(
                              child: InfoCard(
                                title: "Balance",
                                amount: "₹${balance.toStringAsFixed(2)}",
                                amountFontSize: kFontLarge,
                                amountColor: balance < 0 ? Colors.red : null,
                              ),
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
                    ],
                  ),
                ),
              )
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: "Search Customer",
                hintStyle: TextStyle(fontSize: kFontMedium),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xff205781)),
                ),
                filled: true,
                fillColor: const Color(0xFFF5F5F5),
              ),
              style: TextStyle(fontSize: kFontMedium),
              onChanged: (value) {
                setState(() {
                  searchQuery = value;
                });
              },
            ),
          ),
          Expanded(
            child: isLoadingAccounts
                ? const Center(child: CircularProgressIndicator())
                : filteredAccounts.isEmpty
                ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.person_outline,
                      size: 70, color: Colors.grey.withOpacity(0.7)),
                  const SizedBox(height: 12),
                  Text(
                    "No customer available",
                    style: TextStyle(
                        fontSize: kFontLarge, color: Colors.grey[700]),
                  ),
                ],
              ),
            )
                : ListView.builder(
              itemCount: filteredAccounts.length,
              itemBuilder: (context, index) {
                final acc = filteredAccounts[index];
                final name = acc['name'] ?? "Unknown Name";
                final totalBalance = acc['total_Balance'] ?? 0.0;
                final accountId = acc['accountId'];
                final companyId = selectedCompanyId;
                // Use backend lastUpdate (from backend) here:
                final lastUpdateStr = getFormattedLastUpdate(acc);

                return InkWell(
                  onTap: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CustomerDetails(
                          accountId: accountId,
                          companyId: companyId!,
                        ),
                      ),
                    );
                    if (result == true && companyId != null) {
                      fetchAccounts(companyId);
                    }
                  },
                  child: CustomerTile(
                    name: name,
                    amount: "₹${totalBalance.toStringAsFixed(2)}",
                    lastUpdate: lastUpdateStr, // shows "Last update: $lastUpdate" in UI
                  ),
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: GestureDetector(
          onTap: () {
            if (selectedCompanyId == null) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text("Please select a company first!")));
              return;
            }
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    AddCustomerPage(companyId: selectedCompanyId!),
              ),
            ).then((value) {
              if (value == true) fetchAccounts(selectedCompanyId!);
            });
          },
          child: Container(
            height: 50,
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFF205781),
              borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(15), topRight: Radius.circular(15)),
            ),
            alignment: Alignment.center,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.person, color: Colors.white, size: 28),
                SizedBox(width: 12),
                Text(
                  "Add Customer",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: kFontLarge,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class InfoCard extends StatelessWidget {
  final String title;
  final String amount;
  final double amountFontSize;
  final Color? amountColor;

  const InfoCard({
    required this.title,
    required this.amount,
    this.amountFontSize = kFontLarge,
    this.amountColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(title,
            style: TextStyle(color: Colors.grey, fontSize: kFontMedium)),
        const SizedBox(height: 4),
        Text(
          amount,
          style: TextStyle(
            color: amountColor ?? const Color(0xFF2D486C),
            fontSize: amountFontSize,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class CustomerTile extends StatelessWidget {
  final String name;
  final String amount;
  final String? lastUpdate;

  const CustomerTile({required this.name, required this.amount, this.lastUpdate});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(
          title: Text(name, style: TextStyle(fontSize: kFontLarge)),
          subtitle: lastUpdate != null
              ? Padding(
            padding: const EdgeInsets.only(top: 2.0),
            child: Text(
              " $lastUpdate",
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          )
              : null,
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: const Color(0xCEDF9F4D).withOpacity(0.18),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              amount,
              style: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w400,
                fontSize: kFontLarge,
              ),
            ),
          ),
        ),
        const Divider(),
      ],
    );
  }
}