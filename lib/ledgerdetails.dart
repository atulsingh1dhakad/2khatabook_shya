import 'dart:convert';
import 'package:Calculator/presentation/youwillget.dart';
import 'package:Calculator/presentation/youwillgive.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'LIST_LANG.dart'; // For localization (add this file for i18n/l10n support)

const double kFontSmall = 14;
const double kFontMedium = 16;
const double kFontLarge = 18;
const double kFontXLarge = 20;

class LedgerDetails extends StatefulWidget {
  final String ledgerId;
  final String accountName;
  final String accountImageUrl;
  final String companyId;
  final String accountId;

  const LedgerDetails({
    Key? key,
    required this.ledgerId,
    required this.accountName,
    required this.companyId,
    required this.accountId,
    this.accountImageUrl = '',
  }) : super(key: key);

  @override
  State<LedgerDetails> createState() => _LedgerDetailsState();
}

class _LedgerDetailsState extends State<LedgerDetails> {
  bool isLoading = true;
  String? errorMessage;
  Map<String, dynamic>? ledgerEntry;
  Map<String, dynamic>? totals;

  // Permission control
  bool _accessLoaded = false;
  bool _isViewOnly = false;
  String _userType = '';
  String _userId = '';
  String _companyPermission = '';

  @override
  void initState() {
    super.initState();
    _fetchUserInfoAndAccess();
    fetchLedgerEntry();
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
        print('ERROR: userId or userType is empty! Check login logic and shared preferences.');
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

  Future<String?> getAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString("auth_token");
  }

  Future<void> fetchLedgerEntry() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final authKey = await getAuthToken();
      if (authKey == null) {
        throw Exception(AppStrings.getString("authTokenMissing"));
      }

      final url = "http://account.galaxyex.xyz/v1/user/api//account/get-ledger/${widget.accountId}";
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
          final List<dynamic> ledgerList = jsonData['data'] ?? [];
          final entry = ledgerList.firstWhere(
                (e) => e['ledgerId'].toString() == widget.ledgerId,
            orElse: () => null,
          );
          setState(() {
            ledgerEntry = entry;
            totals = jsonData['totals'];
            isLoading = false;
          });
        } else {
          setState(() {
            errorMessage = jsonData['meta']?['msg'] ?? AppStrings.getString("failedToFetchEntry");
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

  String formatDateTime(int milliseconds) {
    final dt = DateTime.fromMillisecondsSinceEpoch(milliseconds);
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final ampm = dt.hour < 12 ? 'AM' : 'PM';
    return "${dt.day.toString().padLeft(2, '0')} "
        "${_monthName(dt.month)} "
        "${dt.year} • "
        "${hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} $ampm";
  }

  String _monthName(int month) {
    const months = [
      "Jan", "Feb", "Mar", "Apr", "May", "Jun",
      "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"
    ];
    return months[(month - 1).clamp(0, 11)];
  }

  Future<void> _confirmAndDelete() async {
    if (_isViewOnly) {
      _showNoPermissionDialog();
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppStrings.getString("deleteEntry")),
        content: Text(AppStrings.getString("confirmDeleteEntry")),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(AppStrings.getString("cancel")),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(AppStrings.getString("delete"), style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      deleteLedgerEntry();
    }
  }

  Future<void> deleteLedgerEntry() async {
    final authKey = await getAuthToken();
    if (authKey == null) {
      _showSnackBar(AppStrings.getString("authTokenMissing"));
      return;
    }
    final url = "http://account.galaxyex.xyz/v1/user/api/setting/remove-ledger/${widget.ledgerId}";
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
          _showSnackBar(AppStrings.getString("entryDeletedSuccessfully"));
          await Future.delayed(const Duration(milliseconds: 500));
          Navigator.of(context).pop(true);
        } else {
          _showSnackBar(jsonData['meta']?['msg'] ?? AppStrings.getString("failedToDeleteEntry"));
        }
      } else {
        _showSnackBar("${AppStrings.getString("failedToDeleteEntry")}, ${AppStrings.getString("serverError")}: ${response.statusCode}");
      }
    } catch (e) {
      _showSnackBar("${AppStrings.getString("errorDeletingEntry")}: $e");
    }
  }

  void _showSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
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
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        backgroundColor: Colors.grey[200],
        appBar: AppBar(
          backgroundColor: const Color(0xFF3275A5),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            AppStrings.getString("entryDetails"),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
        ),
        body: isLoading
            ? const Center(child: CircularProgressIndicator())
            : errorMessage != null
            ? Center(child: Text(errorMessage!, style: const TextStyle(fontSize: kFontLarge)))
            : _buildDetails(context),
        bottomNavigationBar: ledgerEntry == null
            ? null
            : SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isViewOnly ? _showNoPermissionDialog : _confirmAndDelete,
                    icon: Icon(Icons.delete, color: _isViewOnly ? Colors.grey : Colors.red, size: 18),
                    label: Text(
                      AppStrings.getString("delete").toUpperCase(),
                      style: TextStyle(
                        color: _isViewOnly ? Colors.grey : Colors.red,
                        fontWeight: FontWeight.w600,
                        fontSize: kFontMedium,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      side: BorderSide(color: _isViewOnly ? Colors.grey : Colors.red),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isViewOnly
                        ? _showNoPermissionDialog
                        : () {
                      // Implement share functionality
                    },
                    icon: Icon(Icons.share, color: _isViewOnly ? Colors.grey[200] : Colors.white, size: 18),
                    label: Text(
                      AppStrings.getString("share").toUpperCase(),
                      style: TextStyle(
                        fontSize: kFontMedium,
                        color: _isViewOnly ? Colors.grey : Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isViewOnly ? Colors.grey : const Color(0xFF265E85),
                      padding: const EdgeInsets.symmetric(vertical: 12,),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetails(BuildContext context) {
    final entry = ledgerEntry!;
    final accountName = widget.accountName;
    final credit = double.tryParse(entry['creditAmount']?.toString() ?? "0") ?? 0;
    final debit = double.tryParse(entry['debitAmount']?.toString() ?? "0") ?? 0;
    final dateMillis = entry['ledgerDate'] ?? 0;
    final runningBalance = double.tryParse(entry['runningBalance']?.toString() ?? "0") ?? 0;
    final remark = entry['remark'] ?? "";
    final isCredit = credit > 0;
    final isDebit = debit > 0;
    final youGot = isCredit && !isDebit;
    final youGave = isDebit && !isCredit;

    final avatar = widget.accountImageUrl.isEmpty
        ? const CircleAvatar(
      radius: 22,
    )
        : CircleAvatar(
      radius: 22,
      backgroundImage: NetworkImage(widget.accountImageUrl),
    );

    String amountLabel;
    Color amountColor;
    double amountValue;

    if (youGot) {
      amountLabel = AppStrings.getString("youWillGet");
      amountColor = const Color(0xFF205781);
      amountValue = credit;
    } else {
      amountLabel = AppStrings.getString("youWillGive");
      amountColor = Colors.red;
      amountValue = debit;
    }

    final accountTotals = totals ?? {};
    final totalCredit = accountTotals['totalCreditAmount'] ?? "";
    final totalDebit = accountTotals['totalDebitAmount'] ?? "";
    final totalBalance = accountTotals['totalBalance'] ?? "";

    // --- FIX: handle path as String or List<String>
    List<String> imageUrls = [];
    dynamic path = entry['path'];
    if (path is String && path.isNotEmpty) {
      imageUrls.add(path);
    } else if (path is List) {
      imageUrls = List<String>.from(path.whereType<String>());
    }

    final runningBalanceColor =
    runningBalance > 0 ? const Color(0xFF205781) : Colors.red;

    return Column(
      children: [
        Container(
            color: const Color(0xFF26698F),
            width: double.infinity,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 20, 10, 10),
                  child: Card(
                    color: Colors.white,
                    elevation: 1.5,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 14, 12, 2),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              avatar,
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      accountName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: kFontLarge,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      formatDateTime(dateMillis),
                                      style: const TextStyle(
                                        color: Colors.grey,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w400,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    "₹ ${amountValue.toStringAsFixed(0)}",
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: kFontLarge,
                                      color: amountColor,
                                    ),
                                  ),
                                  Text(
                                    amountLabel,
                                    style: TextStyle(
                                      color: Colors.grey[700],
                                      fontSize: 13,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          if (imageUrls.isNotEmpty) ...[
                            const Divider(),
                            const SizedBox(height: 18),
                            Text(
                              AppStrings.getString("photoAttachments"),
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                                fontSize: 12,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: imageUrls.map((url) => ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: GestureDetector(
                                  onTap: () {
                                    showDialog(
                                      context: context,
                                      builder: (_) => Dialog(
                                        child: Image.network(url, fit: BoxFit.contain),
                                      ),
                                    );
                                  },
                                  child: Image.network(
                                    url,
                                    width: 100,
                                    height: 68,
                                    fit: BoxFit.cover,
                                    errorBuilder: (ctx, err, stack) =>
                                    const Icon(Icons.broken_image, size: 40),
                                  ),
                                ),
                              )).toList(),
                            ),
                          ],
                          const SizedBox(height: 15),
                          const Divider(height: 1),
                          const SizedBox(height: 15),
                          Row(
                            children: [
                              Text(
                                AppStrings.getString("runningBalance"),
                                style: const TextStyle(fontSize: 15),
                              ),
                              const Spacer(),
                              Text(
                                "₹ $totalBalance",
                                style: TextStyle(
                                  color: runningBalanceColor,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 15),
                          const Divider(height: 1),
                          if (totalCredit != "" && totalDebit != "" && totalBalance != "")
                            const SizedBox(height: 8),
                          Center(
                            child: TextButton.icon(
                              onPressed: _isViewOnly
                                  ? _showNoPermissionDialog
                                  : () async {
                                if (youGot) {
                                  final result = await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => YouWillGetPage(
                                        accountId: widget.accountId,
                                        accountName: accountName,
                                        companyId: widget.companyId,
                                        ledgerId: widget.ledgerId,
                                        editCredit: credit,
                                        editRemark: remark,
                                        editDate: DateTime.fromMillisecondsSinceEpoch(dateMillis),
                                      ),
                                    ),
                                  );
                                  if (result == true) {
                                    fetchLedgerEntry();
                                  }
                                } else {
                                  final result = await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => YouWillGivePage(
                                        accountId: widget.accountId,
                                        accountName: accountName,
                                        companyId: widget.companyId,
                                        ledgerId: widget.ledgerId,
                                        editDebit: debit,
                                        editRemark: remark,
                                        editDate: DateTime.fromMillisecondsSinceEpoch(dateMillis),
                                      ),
                                    ),
                                  );
                                  if (result == true) {
                                    fetchLedgerEntry();
                                  }
                                }
                              },
                              icon: Icon(Icons.edit, color: _isViewOnly ? Colors.grey : const Color(0xFF265E85), size: 18),
                              label: Text(
                                AppStrings.getString("editEntry").toUpperCase(),
                                style: TextStyle(
                                  color: _isViewOnly ? Colors.grey : const Color(0xFF265E85),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20,)
              ],
            )
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 20, 10, 10),
          child: Column(
            children: [
              const SizedBox(height: 13),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFF198754), width: 1.2),
                      shape: BoxShape.circle,
                    ),
                    padding: const EdgeInsets.all(6),
                    child: const Icon(Icons.verified, color: Color(0xFF198754), size: 18),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    AppStrings.getString("safeAndSecure"),
                    style: const TextStyle(
                      color: Color(0xFF198754),
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}