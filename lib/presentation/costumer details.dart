import 'dart:convert';
import 'dart:io';
import 'package:Calculator/presentation/sidebarscreen.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import '../LIST_LANG.dart';
import '../ledgerdetails.dart';
import 'youwillgive.dart';
import 'youwillget.dart';
import 'Addcustomerscreen.dart';
import '../../main.dart';

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

class _CustomerDetailsState extends State<CustomerDetails>
    with WidgetsBindingObserver, RouteAware {
  bool isLoading = true;
  String? errorMessage;
  List<dynamic> ledger = [];
  double totalCredit = 0;
  double totalDebit = 0;
  double totalBalance = 0;
  String accountName = '';
  String accountRemark = '';
  bool dataChanged = false;

  // Download state
  bool isDownloadingPdf = false;
  bool isDownloadingExcel = false;

  // Permission control
  bool _accessLoaded = false;
  bool _isViewOnly = false;
  String _userType = '';
  String _userId = '';
  String _companyPermission = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _fetchUserInfoAndAccess();
    fetchAllData();
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
      if ((_userId).isEmpty || (_userType).isEmpty) {
        // Handle missing user info
      }
      if (_userId.isNotEmpty) {
        await _fetchUserAccess(_userId, widget.companyId);
      } else {
        setState(() {
          _accessLoaded = true;
          _isViewOnly = false;
          _companyPermission = '';
        });
      }
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
          if (permission.toUpperCase() == 'VIEW') {
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

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)!);
  }

  @override
  void didPopNext() {
    fetchAllData();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      fetchAllData();
    }
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
    if (authKey == null) throw Exception("Authentication token missing. Please log in.");
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
    final url =
        "http://account.galaxyex.xyz/v1/user/api//account/get-ledger/${widget.accountId}";
    final authKey = await getAuthToken();
    if (authKey == null) throw Exception("Authentication token missing. Please log in.");
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
              jsonData['totals']?['totalCreditAmount']?.toString() ?? "0") ?? 0;
          totalDebit = double.tryParse(
              jsonData['totals']?['totalDebitAmount']?.toString() ?? "0") ?? 0;
          totalBalance = double.tryParse(
              jsonData['totals']?['totalBalance']?.toString() ?? "0") ?? 0;
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

  Future<void> _handleEntryChange(Future<dynamic> future) async {
    final value = await future;
    if (value == true) {
      await fetchAllData();
      setState(() {
        dataChanged = true;
      });
    }
  }

  Future<bool> _onWillPop() async {
    Navigator.pop(context, dataChanged);
    return false;
  }

  void _showNoPermissionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppStrings.getString("permissionDenied")),
        content: Text(AppStrings.getString("noPermissionForThisAction")),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(AppStrings.getString("close")),
          ),
        ],
      ),
    );
  }

  Future<bool> requestStoragePermission() async {
    if (!Platform.isAndroid) return true;
    int sdkInt = 30;
    try {
      sdkInt = 31; // Assume Android 11+ for most new devices.
    } catch (_) {}
    if (sdkInt >= 30) {
      var status = await Permission.manageExternalStorage.status;
      if (!status.isGranted) {
        status = await Permission.manageExternalStorage.request();
        if (!status.isGranted) {
          await openAppSettings();
          return false;
        }
      }
      return true;
    } else {
      var status = await Permission.storage.status;
      if (!status.isGranted) {
        status = await Permission.storage.request();
        if (!status.isGranted) return false;
      }
      return true;
    }
  }

  Future<void> downloadPdfForAccount() async {
    setState(() { isDownloadingPdf = true; });
    try {
      if (!await requestStoragePermission()) {
        setState(() { isDownloadingPdf = false; });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Storage permission denied.")),
        );
        return;
      }
      final prefs = await SharedPreferences.getInstance();
      final authKey = prefs.getString("auth_token");
      if (authKey == null) throw Exception("Missing auth token");

      final now = DateTime.now();
      String nowString = "${now.day.toString().padLeft(2, '0')}-${now.month.toString().padLeft(2, '0')}-${now.year} "
          "${(now.hour % 12 == 0 ? 12 : now.hour % 12).toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')} "
          "${now.hour < 12 ? "AM" : "PM"}";

      final Map<String, String> queryParams = {
        "companyName": accountName,
        "updateAt": nowString,
        "totelCredit": totalCredit.toStringAsFixed(2),
        "totelDebit": totalDebit.toStringAsFixed(2),
        "totelBalance": totalBalance.toStringAsFixed(2),
        "row": jsonEncode(ledger),
      };

      final uri = Uri.http(
        "account.galaxyex.xyz",
        "/v1/user/api/account/generate-pdf",
        queryParams,
      );

      final response = await http.get(uri, headers: {
        "Authkey": authKey,
        "Content-Type": "application/json",
      });

      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
        if (response.bodyBytes.length > 4 &&
            response.bodyBytes[0] == 0x25 &&
            response.bodyBytes[1] == 0x50 &&
            response.bodyBytes[2] == 0x44 &&
            response.bodyBytes[3] == 0x46) {
          final directory = await getApplicationDocumentsDirectory();
          final filePath = '${directory.path}/customer_${accountName}_${DateTime.now().millisecondsSinceEpoch}.pdf';
          final file = File(filePath);
          await file.writeAsBytes(response.bodyBytes);
          setState(() { isDownloadingPdf = false; });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("PDF downloaded: $filePath")),
          );
          await OpenFile.open(filePath);
        } else {
          setState(() { isDownloadingPdf = false; });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Invalid PDF data.")),
          );
        }
      } else {
        setState(() { isDownloadingPdf = false; });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to download PDF: ${response.statusCode}")),
        );
      }
    } catch (e) {
      setState(() { isDownloadingPdf = false; });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
  }

  Future<void> downloadExcelForAccount() async {
    setState(() { isDownloadingExcel = true; });
    try {
      if (!await requestStoragePermission()) {
        setState(() { isDownloadingExcel = false; });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Storage permission denied.")),
        );
        return;
      }
      final prefs = await SharedPreferences.getInstance();
      final authKey = prefs.getString("auth_token");
      if (authKey == null) throw Exception("Missing auth token");

      final now = DateTime.now();
      String nowString = "${now.day.toString().padLeft(2, '0')}-${now.month.toString().padLeft(2, '0')}-${now.year} "
          "${(now.hour % 12 == 0 ? 12 : now.hour % 12).toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')} "
          "${now.hour < 12 ? "AM" : "PM"}";
      final Map<String, String> queryParams = {
        "companyName": accountName,
        "updateAt": nowString,
        "totelCredit": totalCredit.toStringAsFixed(2),
        "totelDebit": totalDebit.toStringAsFixed(2),
        "totelBalance": totalBalance.toStringAsFixed(2),
        "row": jsonEncode(ledger),
      };

      final uri = Uri.http(
        "account.galaxyex.xyz",
        "/v1/user/api/account/generate-excel",
        queryParams,
      );

      final response = await http.get(uri, headers: {
        "Authkey": authKey,
        "Content-Type": "application/json",
      });

      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
        final directory = await getApplicationDocumentsDirectory();
        final filePath = "${directory.path}/customer_${accountName}_${DateTime.now().millisecondsSinceEpoch}.xlsx";
        final file = File(filePath);
        await file.writeAsBytes(response.bodyBytes);
        setState(() { isDownloadingExcel = false; });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Excel downloaded: $filePath")),
        );
        await OpenFile.open(filePath);
      } else {
        setState(() { isDownloadingExcel = false; });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to download Excel: ${response.statusCode}")),
        );
      }
    } catch (e) {
      setState(() { isDownloadingExcel = false; });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
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
      "Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"
    ];
    return months[(month - 1).clamp(0, 11)];
  }

  List<double> _reversedRunningBalances() {
    double sum = 0;
    List<double> balances = List.filled(ledger.length, 0);
    for (int i = ledger.length - 1; i >= 0; i--) {
      final credit = double.tryParse(ledger[i]['creditAmount']?.toString() ?? "0") ?? 0;
      final debit = double.tryParse(ledger[i]['debitAmount']?.toString() ?? "0") ?? 0;
      sum += credit - debit;
      balances[i] = sum;
    }
    return balances;
  }

  double _getResponsiveFontSize(String value, double maxWidth, {double minFont = 10, double maxFont = 14.5}) {
    for (double font = maxFont; font >= minFont; font -= 0.5) {
      final estWidth = value.length * font * 0.58;
      if (estWidth <= maxWidth) return font;
    }
    return minFont;
  }

  Widget buildLedgerItem(Map<String, dynamic> entry, double runningBalance) {
    final credit = double.tryParse(entry['creditAmount']?.toString() ?? "0") ?? 0;
    final debit = double.tryParse(entry['debitAmount']?.toString() ?? "0") ?? 0;
    final dateMillis = entry['ledgerDate'] ?? 0;
    final remark = entry['remark'] ?? "";
    final ledgerId = entry['ledgerId']?.toString() ?? "";

    final String balanceText = (runningBalance < 0
        ? "-₹${runningBalance.abs().toStringAsFixed(2)}"
        : "₹${runningBalance.toStringAsFixed(2)}");

    List<String> imageUrls = [];
    dynamic path = entry['path'];
    if (path is String && path.isNotEmpty) {
      imageUrls.add(path);
    } else if (path is List) {
      imageUrls = List<String>.from(path.whereType<String>());
    }

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
          setState(() {
            dataChanged = true;
          });
        }
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final debitMaxWidth = 80.0 - 20.0;
          final creditMaxWidth = 80.0 - 20.0;

          final debitText = debit == 0 ? "" : "₹${debit.toStringAsFixed(2)}";
          final creditText = credit == 0 ? "" : "₹${credit.toStringAsFixed(2)}";

          final debitFontSize = _getResponsiveFontSize(debitText, debitMaxWidth);
          final creditFontSize = _getResponsiveFontSize(creditText, creditMaxWidth);

          return Container(
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
                  Expanded(
                    flex: 7,
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
                              color: const Color(0xCEDF9F4D).withOpacity(0.18),
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
                        if (imageUrls.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 6.0),
                            child: Row(
                              children: imageUrls.map((url) => Padding(
                                padding: const EdgeInsets.only(right: 4),
                                child: GestureDetector(
                                  onTap: () {
                                    showDialog(
                                      context: context,
                                      builder: (_) => Dialog(
                                        child: Image.network(url, fit: BoxFit.contain),
                                      ),
                                    );
                                  },
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: Image.network(
                                      url,
                                      width: 48,
                                      height: 48,
                                      fit: BoxFit.cover,
                                      errorBuilder: (ctx, err, stack) =>
                                      const Icon(Icons.broken_image, size: 32),
                                    ),
                                  ),
                                ),
                              )).toList(),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 7,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
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
                              debitText,
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                fontSize: debitFontSize,
                                color: Colors.red,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                        ),
                        Container(
                          width: 80,
                          alignment: Alignment.centerRight,
                          child: credit == 0
                              ? const SizedBox.shrink()
                              : Text(
                            creditText,
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: creditFontSize,
                              color: Color(0xFF198754),
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
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
      label = AppStrings.getString("youWillGive");
      amountTextColor = Colors.red;
      displayAmount = -balance;
    } else if (balance > 0) {
      label = AppStrings.getString("youWillGet");
      amountTextColor = const Color(0xFF198754);
      displayAmount = balance;
    } else {
      label = AppStrings.getString("settledUp");
      amountTextColor = Colors.grey;
      displayAmount = 0.0;
    }

    final reversedRunningBalances = _reversedRunningBalances();

    bool disableButtons = false;
    if (_userType.trim().toUpperCase() == "STAFF") {
      disableButtons = !_accessLoaded || _isViewOnly;
    }

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
                                : AppStrings.getString("loading"),
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        // PDF as image
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: GestureDetector(
                            onTap: isDownloadingPdf ? null : downloadPdfForAccount,
                            child: isDownloadingPdf
                                ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    color: Colors.red[300], strokeWidth: 2))
                                : Image.asset(
                              "assets/images/pdf.png",
                              width: 22,
                              height: 22,
                              fit: BoxFit.contain,
                              color: null,
                            ),
                          ),
                        ),
                        SizedBox(width: 20,),
                        // Excel as image
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: GestureDetector(
                            onTap: isDownloadingExcel ? null : downloadExcelForAccount,
                            child: isDownloadingExcel
                                ? SizedBox(
                                width: 28,
                                height: 28,
                                child: CircularProgressIndicator(
                                    color: Colors.green[700], strokeWidth: 2))
                                : Image.asset(
                              "assets/images/ms-excel.png",
                              width: 22,
                              height: 22,
                              fit: BoxFit.contain,
                              color: null,
                            ),
                          ),
                        ),
                        SizedBox(width: 6,),
                        IconButton(
                          icon: Icon(Icons.edit, color: disableButtons ? Colors.grey[300] : Colors.white),
                          onPressed: disableButtons
                              ? () {
                            _showNoPermissionDialog();
                          }
                              : () async {
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => AddCustomerPage(
                                  companyId: widget.companyId,
                                  initialName: accountName,
                                  initialRemark: accountRemark,
                                  accountId: widget.accountId,
                                  isEdit: true,
                                ),
                              ),
                            );
                            if (result == true) {
                              await fetchAllData();
                              setState(() {
                                dataChanged = true;
                              });
                            }
                          },
                        ),
                        if (_companyPermission.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(left: 8, right: 8),
                            child: Text(
                              '(${_companyPermission.toUpperCase()})',
                              style: const TextStyle(
                                color: Colors.amber,
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
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
            Padding(
              padding: const EdgeInsets.only(
                  left: 18, right: 12, top: 8, bottom: 2),
              child: Row(
                children: [
                  Expanded(
                    flex: 6,
                    child: Text(
                      AppStrings.getString("dateRemark"),
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
                          width: 70,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            AppStrings.getString("youGive"),
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
                            AppStrings.getString("youGet"),
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
                          color: Colors.grey.withOpacity(0.7)),
                      const SizedBox(height: 12),
                      Text(
                        AppStrings.getString("noEntryAvailable"),
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
                    final runningBalance =
                    _reversedRunningBalances()[index];
                    return buildLedgerItem(
                      ledger[index],
                      runningBalance,
                    );
                  },
                ),
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: disableButtons
                            ? () {
                          _showNoPermissionDialog();
                        }
                            : () {
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
                          backgroundColor: disableButtons ? Colors.grey[400] : const Color(0xffc96868),
                          padding: const EdgeInsets.symmetric(
                              vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(7),
                          ),
                        ),
                        child: Text(
                          AppStrings.getString("youGive"),
                          style: const TextStyle(
                              fontSize: kFontLarge,
                              color: Colors.white),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: disableButtons
                            ? () {
                          _showNoPermissionDialog();
                        }
                            : () {
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
                          backgroundColor: disableButtons ? Colors.grey[400] : const Color(0xFF198754),
                          padding: const EdgeInsets.symmetric(
                              vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(7),
                          ),
                        ),
                        child: Text(
                          AppStrings.getString("youGet"),
                          style: const TextStyle(
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