import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shya_khatabook/presentation/Addcompanyscreen.dart';
import 'package:shya_khatabook/presentation/Addcustomerscreen.dart';
import 'package:shya_khatabook/presentation/sidebarscreen.dart';

import 'costumer details.dart';


class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? selectedCompanyId;
  String? selectedCompanyName;
  List<dynamic> companies = [];
  List<dynamic> accounts = [];
  bool isLoadingCompanies = true;
  bool isLoadingAccounts = false;
  String? errorMsg;
  int totalCredit = 0;
  int totalDebit = 0;
  int balance = 0;
  bool showCompanyMenu = false;
  String searchQuery = "";

  @override
  void initState() {
    super.initState();
    fetchCompanies();
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
          final List<dynamic> fetchedCompanies = data['data'];
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
            errorMsg = "Failed to fetch company data!";
            isLoadingCompanies = false;
          });
        }
      } else {
        setState(() {
          errorMsg = "Failed to fetch companies: ${response.statusCode}";
          isLoadingCompanies = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMsg = "Error fetching companies: $e";
        isLoadingCompanies = false;
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
          errorMsg = "No authentication token found. Please log in again.";
          isLoadingAccounts = false;
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
            totalCredit = data['overallTotals']?['totalCreditSum'] ?? 0;
            totalDebit = data['overallTotals']?['totalDebitSum'] ?? 0;
            balance = totalCredit - totalDebit;
            isLoadingAccounts = false;
            errorMsg = null;
          });
        } else {
          setState(() {
            errorMsg = "Failed to fetch accounts data!";
            isLoadingAccounts = false;
          });
        }
      } else {
        setState(() {
          errorMsg = "Failed to fetch accounts: ${response.statusCode}";
          isLoadingAccounts = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMsg = "Error fetching accounts: $e";
        isLoadingAccounts = false;
      });
    }
  }

  void onCompanyChanged(String? newCompanyId, String? newCompanyName) {
    setState(() {
      selectedCompanyId = newCompanyId;
      selectedCompanyName = newCompanyName;
      showCompanyMenu = false;
    });
    if (newCompanyId != null) {
      fetchAccounts(newCompanyId);
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
                  setState(() {
                    showCompanyMenu = !showCompanyMenu;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF205781),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: Colors.white,
                        child: Text(
                          selectedCompanyName != null
                              ? getInitials(
                            selectedCompanyName!,
                            companies.indexWhere((c) => c['companyName'] == selectedCompanyName),
                          )
                              : '',
                          style: const TextStyle(
                              color: Color(0xFF205781),
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          selectedCompanyName ?? "Select Company",
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 20,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const Icon(Icons.arrow_drop_down, color: Colors.white, size: 32),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
                child: const Icon(Icons.settings_suggest_outlined, color: Colors.white),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const settingscreen()),
                  );
                }
            )
          ],
        ),
        toolbarHeight: 70,
      ),
      body: Stack(
        children: [
          errorMsg != null
              ? Center(child: Text(errorMsg!))
              : Column(
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
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                InfoCard(
                                  title: "You Will Give",
                                  amount: "₹${totalDebit.toStringAsFixed(2)}",
                                ),
                                InfoCard(
                                  title: "You Will Get",
                                  amount: "₹${totalCredit.toStringAsFixed(2)}",
                                ),
                                InfoCard(
                                  title: "Balance",
                                  amount: "₹${balance.toStringAsFixed(2)}",
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
                                Icon(Icons.file_copy, size: 20, color: Colors.grey),
                                SizedBox(width: 8),
                                Text("Get Report"),
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
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Colors.grey),
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF5F5F5),
                  ),
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
                    : ListView.builder(
                  itemCount: filteredAccounts.length,
                  itemBuilder: (context, index) {
                    final acc = filteredAccounts[index];

                    // Safeguard against null values in the account data
                    final name = acc['name'] ?? "Unknown Name";
                    final totalBalance = acc['total_Balance'] ?? 0.0;

                    return InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => CustomerDetails(
                              accountId: "67f0b30781ac4b2c6e941ff9",
                              accountName: "Shiva",
                            ),
                          ),
                        );

                      },
                      child: CustomerTile(
                        name: name,
                        amount: "₹${totalBalance.toStringAsFixed(2)}",
                      ),
                    );
                  },
                ),
              )

            ],
          ),
          // Dropdown Menu Overlay (Smaller, Blurry)
          if (showCompanyMenu)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => showCompanyMenu = false),
                child: Stack(
                  children: [
                    // Blurry background
                    BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 8.0, sigmaY: 8.0),
                      child: Container(
                        color: Colors.black.withOpacity(0.12),
                      ),
                    ),
                    Center(
                      child: Container(
                        width: 320,
                        constraints: const BoxConstraints(maxHeight: 400),
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.93),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.10),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Scrollbar(
                          thumbVisibility: true,
                          radius: const Radius.circular(8),
                          child: ListView(
                            shrinkWrap: true,
                            children: [
                              ...companies.asMap().entries.map((entry) {
                                final index = entry.key;
                                final company = entry.value;
                                final bool isSelected = selectedCompanyId == company['companyId'];
                                return GestureDetector(
                                  onTap: () => onCompanyChanged(
                                      company['companyId'], company['companyName']),
                                  child: Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
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
                                            getInitials(company['companyName'], index),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                              letterSpacing: 1.2,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                company['companyName'],
                                                style: TextStyle(
                                                  color: isSelected ? Colors.white : const Color(0xFF205781),
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 16,
                                                ),
                                              ),
                                              const SizedBox(height: 1),
                                              Text(
                                                "4 Customers", // replace with real value if available
                                                style: TextStyle(
                                                  color: isSelected
                                                      ? Colors.white.withOpacity(0.8)
                                                      : const Color(0xFF205781),
                                                  fontWeight: FontWeight.w400,
                                                  fontSize: 12,
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
                              const SizedBox(height: 3),
                              ElevatedButton.icon(
                                onPressed: () {Navigator.push(
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
                                        fontSize: 15,
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
                                  minimumSize: const Size.fromHeight(40),
                                  padding: const EdgeInsets.symmetric(horizontal: 10),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          // Sticky Add Customer Banner
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => AddCustomerPage()),
                  );
                },
                child: Container(
                  height: 50,
                  width: double.infinity,
                  color: const Color(0xFF205781),
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.add, color: Colors.white, size: 28),
                      SizedBox(width: 12),
                      Text(
                        "Add Customer",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
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

  const InfoCard({required this.title, required this.amount});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(title, style: const TextStyle(color: Colors.grey, fontSize: 14)),
        const SizedBox(height: 4),
        Text(
          amount,
          style: const TextStyle(
            color: Color(0xFF2D486C),
            fontSize: 16,
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

  const CustomerTile({required this.name, required this.amount});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(
          title: Text(name),
          trailing: Text(
            amount,
            style: TextStyle(
              color: name.isNotEmpty ? Colors.green : Colors.grey,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const Divider(),
      ],
    );
  }
}

void main() {
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: HomeScreen(),
  ));
}