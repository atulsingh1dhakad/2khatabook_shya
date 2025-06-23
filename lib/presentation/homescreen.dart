import 'dart:convert';
import 'package:Calculator/presentation/Reportscreen.dart';
import 'package:Calculator/presentation/followup.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../LIST_LANG.dart';
import '../main.dart';
import 'Addcompanyscreen.dart';
import 'Addcustomerscreen.dart';
import 'sidebarscreen.dart';
import 'costumer details.dart';

const double kFontSmall = 12;
const double kFontMedium = 16;
const double kFontLarge = 15;
const double kFontXLarge = 18;

enum FilterBy { all, youWillGet, youWillGive, settled }
enum SortBy { none, mostRecent, highestAmount, byName, oldest, leastAmount }

double toDouble(dynamic value) {
  if (value is int) return value.toDouble();
  if (value is double) return value;
  return double.tryParse(value?.toString() ?? '0') ?? 0.0;
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver, RouteAware {
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

  FilterBy _selectedFilter = FilterBy.all;
  SortBy _selectedSort = SortBy.none;

  AppLifecycleState? _lastLifecycleState;
  bool _didSetInitialCompany = false;

  String _userType = '';
  String _userId = '';
  bool _accessLoaded = false;
  bool _isViewOnly = false;
  String _companyPermission = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _fetchUserInfoAndAccess();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)!);

    if (!_didSetInitialCompany) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args != null && args is Map) {
        selectedCompanyId = args['companyId']?.toString();
        selectedCompanyName = args['companyName']?.toString();
        _didSetInitialCompany = true;
        setState(() {
          isLoadingCompanies = false;
        });
        if (selectedCompanyId != null) {
          fetchAccounts(selectedCompanyId!);
          _fetchUserAccess(_userId, selectedCompanyId!);
        }
      } else {
        fetchCompanies();
        _didSetInitialCompany = true;
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() {
    fetchCompanies();
    if (selectedCompanyId != null) {
      fetchAccounts(selectedCompanyId!);
      _fetchUserAccess(_userId, selectedCompanyId!);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      fetchCompanies();
      if (selectedCompanyId != null) {
        fetchAccounts(selectedCompanyId!);
        _fetchUserAccess(_userId, selectedCompanyId!);
      }
    }
    _lastLifecycleState = state;
  }

  Future<void> _fetchUserInfoAndAccess() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? userId = prefs.getString("userId");
      String? userType = prefs.getString("userType");
      setState(() {
        _userType = userType ?? '';
        _userId = userId ?? '';
      });
    } catch (e) {
      setState(() {
        _userType = '';
        _userId = '';
        _accessLoaded = true;
        _isViewOnly = false;
        _companyPermission = '';
      });
    }
  }

  Future<void> _fetchUserAccess(String userId, String companyId) async {
    if (userId.isEmpty || companyId.isEmpty) {
      setState(() {
        _accessLoaded = true;
        _isViewOnly = false;
        _companyPermission = '';
      });
      return;
    }
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      final authKey = prefs.getString("auth_token");
      final url = "http://account.galaxyex.xyz/v1/user/api//account/get-access/$userId";
      final response = await http.get(
        Uri.parse(url),
        headers: {
          "Authkey": authKey ?? "",
          "Content-Type": "application/json",
        },
      );
      bool viewOnly = false;
      String permission = '';
      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = json.decode(response.body);
        final List compDetails = (jsonData['data']['compnayDetails'] ?? []);
        final access = compDetails.firstWhere(
              (c) => c['companyId'].toString() == companyId,
          orElse: () => null,
        );
        if (access != null) {
          permission = access['action']?.toString() ?? '';
          if (permission.toUpperCase() == "VIEW") {
            viewOnly = true;
          }
        }
      }
      setState(() {
        _accessLoaded = true;
        _isViewOnly = viewOnly;
        _companyPermission = permission;
      });
    } catch (e) {
      setState(() {
        _accessLoaded = true;
        _isViewOnly = false;
        _companyPermission = '';
      });
    }
  }

  String getFormattedLastUpdate(Map<String, dynamic> acc) {
    final lastUpdate = acc['lastUpdate'];
    if (lastUpdate == null) return AppStrings.getString('never');
    try {
      DateTime dt;
      if (lastUpdate is int) {
        dt = DateTime.fromMillisecondsSinceEpoch(lastUpdate);
      } else if (lastUpdate is String) {
        dt = DateTime.parse(lastUpdate);
      } else {
        return AppStrings.getString('never');
      }
      final date = "${dt.day.toString().padLeft(2, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.year}";
      final time = "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
      return "$date $time";
    } catch (_) {
      return AppStrings.getString('never');
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
          errorMsg = AppStrings.getString('noAuthToken');
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
            if (selectedCompanyId != null) {
              final selectedCompany = fetchedCompanies.firstWhere(
                    (c) => c['companyId'].toString() == selectedCompanyId,
                orElse: () => fetchedCompanies[0],
              );
              defaultCompanyId = selectedCompany['companyId'];
              defaultCompanyName = selectedCompany['companyName'];
            } else {
              final defaultCompany = fetchedCompanies.firstWhere(
                    (c) => c['companyName'] == "My Company 1",
                orElse: () => fetchedCompanies[0],
              );
              defaultCompanyId = defaultCompany['companyId'];
              defaultCompanyName = defaultCompany['companyName'];
            }
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
            _fetchUserAccess(_userId, defaultCompanyId);
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
            totalCredit = toDouble(data['overallTotals']?['totalCreditSum']);
            totalDebit = toDouble(data['overallTotals']?['totalDebitSum']);
            balance = toDouble(data['overallTotals']?['totalBalanceSum']);
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
      _accessLoaded = false;
      _isViewOnly = false;
      _companyPermission = '';
    });
    if (newCompanyId != null) {
      fetchAccounts(newCompanyId);
      _fetchUserAccess(_userId, newCompanyId);
    }
    Navigator.of(context).pop();
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

  void _showNoPermissionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Permission Denied"),
        content: const Text("You don't have permission for this action."),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("OK"),
          ),
        ],
      ),
    );
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
                  if (companies.isNotEmpty)
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
                                            AppStrings.getString(company['companyName']),
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
                                              AppStrings.getString(company['companyName']),
                                              style: TextStyle(
                                                color: isSelected
                                                    ? Colors.white
                                                    : const Color(0xFF205781),
                                                fontWeight: FontWeight.w600,
                                                fontSize: kFontLarge,
                                              ),
                                            ),
                                            const SizedBox(height: 1),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        height: 30,
                                        width: 30,
                                        decoration: BoxDecoration(
                                          borderRadius: const BorderRadius.all(Radius.circular(50)),
                                          color: isSelected ? Colors.white : const Color(0xFF205781),
                                          border: Border.all(
                                            color: isSelected ? Colors.grey.shade300 : Colors.transparent,
                                            width: 1,
                                          ),
                                        ),
                                        child: GestureDetector(
                                          onTap: () async {
                                            if (!_accessLoaded) return;
                                            if (_isViewOnly) {
                                              _showNoPermissionDialog();
                                              return;
                                            }
                                            Navigator.pop(context);
                                            await Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) => AddCompanyPage(
                                                  companyId: company['companyId'],
                                                  initialName: company['companyName'],
                                                ),
                                              ),
                                            );
                                            fetchCompanies();
                                          },
                                          child: Icon(
                                            Icons.edit,
                                            color: isSelected ? const Color(0xFF205781) : Colors.white,
                                            size: 20,
                                          ),
                                        ),
                                      )
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
                    onPressed: () async {
                      Navigator.pop(context);
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => AddCompanyPage()),
                      );
                      if (result == true) fetchCompanies();
                    },
                    icon: const Icon(Icons.add, size: 20, color: Colors.white),
                    label: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6.0),
                      child: Text(
                        AppStrings.getString("addNewCompany"),
                        style: const TextStyle(
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

  String formatCompactAmount(num amount) {
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

  Color getBalanceColor() {
    if ((totalCredit - totalDebit) < 0) {
      return Colors.red;
    } else if (balance > 0) {
      return const Color(0xFF2D486C);
    } else {
      return Colors.grey;
    }
  }

  Color getCustomerAmountColor(double totalCreditAmount, double totalDebitAmount) {
    double diff = totalCreditAmount - totalDebitAmount;
    return diff < 0 ? Colors.red : const Color(0xFF2D486C);
  }

  List<dynamic> getFilteredAndSortedAccounts() {
    List<dynamic> filtered = accounts.where((acc) {
      final name = (acc['name'] ?? '').toString().toLowerCase();
      final credit = toDouble(acc['totalCreditAmount']);
      final debit = toDouble(acc['totalDebitAmount']);
      final accBalance = toDouble(acc['total_Balance']);
      if (searchQuery.isNotEmpty && !name.contains(searchQuery.toLowerCase())) {
        return false;
      }
      switch (_selectedFilter) {
        case FilterBy.all:
          return true;
        case FilterBy.youWillGet:
          return credit - debit > 0;
        case FilterBy.youWillGive:
          return credit - debit < 0;
        case FilterBy.settled:
          return accBalance == 0;
      }
    }).toList();

    switch (_selectedSort) {
      case SortBy.none:
        break;
      case SortBy.highestAmount:
        filtered.sort((b, a) => (toDouble(a['total_Balance'])).compareTo(toDouble(b['total_Balance'])));
        break;
      case SortBy.mostRecent:
        filtered.sort((a, b) =>
            ((b['lastUpdate'] ?? b['createdAt'] ?? '') ?? '')
                .toString()
                .compareTo(((a['lastUpdate'] ?? a['createdAt'] ?? '') ?? '').toString()));
        break;
      case SortBy.byName:
        filtered.sort((a, b) =>
            ((a['name'] ?? '') as String).toLowerCase().compareTo(((b['name'] ?? '') as String).toLowerCase()));
        break;
      case SortBy.oldest:
        filtered.sort((a, b) =>
            ((a['lastUpdate'] ?? a['createdAt'] ?? '') ?? '')
                .toString()
                .compareTo(((b['lastUpdate'] ?? b['createdAt'] ?? '') ?? '').toString()));
        break;
      case SortBy.leastAmount:
        filtered.sort((a, b) => (toDouble(a['total_Balance'])).compareTo(toDouble(b['total_Balance'])));
        break;
    }
    return filtered;
  }

  void _showFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      isScrollControlled: true,
      builder: (context) {
        FilterBy tempFilter = _selectedFilter;
        SortBy tempSort = _selectedSort;
        return StatefulBuilder(builder: (context, setModalState) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    AppStrings.getString("filterBy"),
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        color: Colors.grey[800]),
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _buildFilterChip(AppStrings.getString("all"), FilterBy.all, tempFilter, setModalState, (val) { tempFilter = val; }),
                    _buildFilterChip(AppStrings.getString("youWillGet"), FilterBy.youWillGet, tempFilter, setModalState, (val) { tempFilter = val; }),
                    _buildFilterChip(AppStrings.getString("youWillGive"), FilterBy.youWillGive, tempFilter, setModalState, (val) { tempFilter = val; }),
                    _buildFilterChip(AppStrings.getString("settledUp"), FilterBy.settled, tempFilter, setModalState, (val) { tempFilter = val; }),
                  ],
                ),
                const SizedBox(height: 20),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    AppStrings.getString("sortBy"),
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        color: Colors.grey[800]),
                  ),
                ),
                const SizedBox(height: 8),
                _buildSortRadio(AppStrings.getString("noneSort"), SortBy.none, tempSort, setModalState, (val) { tempSort = val; }),
                _buildSortRadio(AppStrings.getString("mostRecent"), SortBy.mostRecent, tempSort, setModalState, (val) { tempSort = val; }),
                _buildSortRadio(AppStrings.getString("highestAmount"), SortBy.highestAmount, tempSort, setModalState, (val) { tempSort = val; }),
                _buildSortRadio(AppStrings.getString("byNameSort"), SortBy.byName, tempSort, setModalState, (val) { tempSort = val; }),
                _buildSortRadio(AppStrings.getString("oldestSort"), SortBy.oldest, tempSort, setModalState, (val) { tempSort = val; }),
                _buildSortRadio(AppStrings.getString("leastAmount"), SortBy.leastAmount, tempSort, setModalState, (val) { tempSort = val; }),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF205781),
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () {
                      setState(() {
                        _selectedFilter = tempFilter;
                        _selectedSort = tempSort;
                      });
                      Navigator.pop(context);
                    },
                    child: Text(
                      AppStrings.getString("viewResult"),
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          );
        });
      },
    );
  }

  Widget _buildFilterChip(String label, FilterBy value, FilterBy group, void Function(void Function()) setModalState, void Function(FilterBy) setTemp) {
    final bool selected = value == group;
    return ChoiceChip(
      label: Text(label, style: TextStyle(
        color: selected ? Colors.white : const Color(0xFF205781),
        fontWeight: FontWeight.w600,
      )),
      selected: selected,
      selectedColor: const Color(0xFF205781),
      backgroundColor: Colors.grey[200],
      onSelected: (_) => setModalState(() { setTemp(value); }),
    );
  }

  Widget _buildSortRadio(String label, SortBy value, SortBy group, void Function(void Function()) setModalState, void Function(SortBy) setTemp) {
    final bool selected = value == group;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(
        label,
        style: TextStyle(
          color: selected ? const Color(0xFF205781) : Colors.grey[900],
          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      trailing: Radio<SortBy>(
        value: value,
        groupValue: group,
        onChanged: (sort) => setModalState(() { setTemp(value); }),
        activeColor: const Color(0xFF205781),
      ),
      onTap: () => setModalState(() { setTemp(value); }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredAccounts = getFilteredAndSortedAccounts();

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
                          AppStrings.getString(selectedCompanyName ?? "selectCompany"),
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
                      if (_companyPermission.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Text(
                          '(${_companyPermission.toUpperCase()})',
                          style: const TextStyle(
                            color: Colors.amber,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
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
                        builder: (context) => const SettingsScreen()),
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
                                title: AppStrings.getString("youWillGive"),
                                amount: "₹${formatCompactAmount(totalDebit)}",
                                amountFontSize: 13,
                                amountColor: Colors.red,
                                titleFontSize: 12,
                              ),
                            ),
                            SizedBox(width: 10),
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
                            SizedBox(width: 10),
                            Expanded(
                              child: InfoCard(
                                title: AppStrings.getString("youWillGet"),
                                amount: "₹${formatCompactAmount(totalCredit)}",
                                amountFontSize: 13,
                                amountColor: const Color(0xFF2D486C),
                                titleFontSize: 12,
                              ),
                            ),
                            SizedBox(width: 10),
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
                            SizedBox(width: 10),
                            Expanded(
                              child: InfoCard(
                                title: AppStrings.getString("balance"),
                                amount: "₹${formatCompactAmount(balance)}",
                                amountFontSize: 13,
                                amountColor: getBalanceColor(),
                                titleFontSize: 12,
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
                        child: GestureDetector(
                          onTap: () {
                            if (selectedCompanyId == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(AppStrings.getString("pleaseSelectCompanyFirst")),
                                ),
                              );
                              return;
                            }
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ReportScreen(
                                  companyId: selectedCompanyId,
                                  companyName: selectedCompanyName,
                                ),
                              ),
                            );
                          },
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.file_copy,
                                  size: 20, color: Colors.grey),
                              const SizedBox(width: 8),
                              Text(AppStrings.getString("getReport"),
                                  style: const TextStyle(fontSize: 12)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 49,
                    child: TextField(
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search),
                        hintText: AppStrings.getString("searchCustomer"),
                        hintStyle: TextStyle(fontSize: kFontMedium),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Color(0xff205781)),
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF5F5F5),
                        contentPadding: const EdgeInsets.symmetric(vertical: 0),
                      ),
                      style: TextStyle(fontSize: kFontMedium),
                      onChanged: (value) {
                        setState(() {
                          searchQuery = value;
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  height: 49,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      elevation: 0,
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF205781),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: const BorderSide(color: Color(0xFF205781), width: 1),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                    ),
                    icon: const Icon(Icons.filter_alt_outlined, color: Color(0xFF205781)),
                    label: Text(AppStrings.getString("filters"),
                        style: const TextStyle(color: Color(0xFF205781), fontWeight: FontWeight.w600)),
                    onPressed: _showFilterBottomSheet,
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  height: 49,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      elevation: 0,
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF205781),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: const BorderSide(color: Color(0xFF205781), width: 1),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                    ),
                    icon: const Icon(Icons.add_circle_outline, color: Color(0xFF205781)),
                    label: Text(AppStrings.getString("followUp"),
                        style: const TextStyle(color: Color(0xFF205781), fontWeight: FontWeight.w600)),
                    onPressed: () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => FollowupScreen(),));
                    },
                  ),
                ),
              ],
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
                  Icon(Icons.person_outline, size: 70, color: Colors.grey.withOpacity(0.7)),
                  const SizedBox(height: 12),
                  Text(
                    AppStrings.getString(companies.isEmpty ? "noCompanyAvailable" : "noCustomerAvailable"),
                    style: TextStyle(fontSize: kFontLarge, color: Colors.grey[700]),
                  ),

                ],
              ),
            )
                : ListView.builder(
              itemCount: filteredAccounts.length,
              itemBuilder: (context, index) {
                final acc = filteredAccounts[index];
                final name = acc['name'] ?? "Unknown Name";
                final totalCreditAmount = toDouble(acc['totalCreditAmount']);
                final totalDebitAmount = toDouble(acc['totalDebitAmount']);
                final totalBalance = toDouble(acc['total_Balance']);
                final accountId = acc['accountId'];
                final companyId = selectedCompanyId;
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
                    amount: "₹${formatCompactAmount(totalBalance)}",
                    lastUpdate: lastUpdateStr,
                    amountColor: getCustomerAmountColor(totalCreditAmount, totalDebitAmount),
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
            if (!_accessLoaded) return;
            if (_isViewOnly) {
              _showNoPermissionDialog();
              return;
            }
            if (selectedCompanyId == null) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(AppStrings.getString("pleaseSelectCompanyFirst"))));
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
          child: Opacity(
            opacity: (!_accessLoaded || _isViewOnly) ? 0.5 : 1.0,
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
                children: [
                  const Icon(Icons.person, color: Colors.white, size: 28),
                  const SizedBox(width: 12),
                  Text(
                    AppStrings.getString("addCustomer"),
                    style: const TextStyle(
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
      ),
    );
  }
}

class InfoCard extends StatelessWidget {
  final String title;
  final String amount;
  final double amountFontSize;
  final Color amountColor;
  final double titleFontSize;

  const InfoCard({
    required this.title,
    required this.amount,
    this.amountFontSize = kFontLarge,
    required this.amountColor,
    this.titleFontSize = 11,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          title,
          style: TextStyle(
            color: Colors.grey,
            fontSize: titleFontSize,
          ),
        ),
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

class CustomerTile extends StatelessWidget {
  final String name;
  final String amount;
  final String? lastUpdate;
  final Color amountColor;

  const CustomerTile({
    required this.name,
    required this.amount,
    this.lastUpdate,
    required this.amountColor,
  });

  @override
  Widget build(BuildContext context) {
    Color backgroundColor;
    if (amountColor == Colors.red) {
      backgroundColor = const Color(0xFFFFEBEE); // light red shade
    } else if (amountColor == const Color(0xFF2D486C)) {
      backgroundColor = const Color(0xFFE3ECF6); // light blue shade
    } else {
      backgroundColor = const Color(0xCEDF9F4D).withOpacity(0.18); // default
    }

    return Column(
      children: [
        ListTile(
          title: Text(name, style: const TextStyle(fontSize: kFontLarge)),
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
              color: backgroundColor,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              amount,
              style: TextStyle(
                color: amountColor,
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