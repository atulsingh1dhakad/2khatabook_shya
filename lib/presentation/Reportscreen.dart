import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import '../LIST_LANG.dart';

class ReportScreen extends StatefulWidget {
  final String? companyId;
  final String? companyName; // <-- Accept companyName from navigation
  const ReportScreen({Key? key, this.companyId, this.companyName}) : super(key: key);

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  bool isLoading = true;
  bool isDownloading = false;
  bool isExcelGenerating = false;
  String? errorMessage;
  List<Map<String, dynamic>> ledgerList = [];
  Map<String, dynamic> totals = {};
  DateTime? startDate;
  DateTime? endDate;

  @override
  void initState() {
    super.initState();
    fetchReport();
  }

  Future<bool> requestStoragePermission() async {
    if (!Platform.isAndroid) return true;
    int sdkInt = 30;
    try {} catch (_) {}
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
          final List<Map<String, dynamic>> sortedData = data.cast<Map<String, dynamic>>();
          sortedData.sort((a, b) {
            int aDate = int.tryParse(a['ledgerDate']?.toString() ?? "0") ?? 0;
            int bDate = int.tryParse(b['ledgerDate']?.toString() ?? "0") ?? 0;
            return bDate.compareTo(aDate);
          });
          setState(() {
            ledgerList = sortedData;
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

  String toTitleCase(String text) {
    if (text.isEmpty) return text;
    return text
        .split(' ')
        .map((word) => word.isEmpty
        ? word
        : word[0].toUpperCase() + word.substring(1).toLowerCase())
        .join(' ');
  }

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

  List<double?> runningBalancesForList(List<Map<String, dynamic>> list) {
    double sum = 0;
    List<double?> balances = List.filled(list.length, null);
    for (int i = list.length - 1; i >= 0; i--) {
      final credit = double.tryParse(list[i]['creditAmount']?.toString() ?? "0") ?? 0;
      final debit = double.tryParse(list[i]['debitAmount']?.toString() ?? "0") ?? 0;
      sum += credit - debit;
      balances[i] = sum;
    }
    return balances;
  }

  Future<void> _pickDate({required bool isStart}) async {
    DateTime initialDate = isStart ? (startDate ?? DateTime.now()) : (endDate ?? DateTime.now());
    DateTime firstDate = DateTime(2000);
    DateTime lastDate = DateTime(2100);

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
    );

    if (picked != null) {
      setState(() {
        if (isStart) {
          startDate = picked;
          if (endDate != null && endDate!.isBefore(startDate!)) {
            endDate = startDate;
          }
        } else {
          endDate = picked;
          if (startDate != null && startDate!.isAfter(endDate!)) {
            startDate = endDate;
          }
        }
      });
    }
  }

  String getDateText(DateTime? date, String defaultText) {
    if (date == null) return defaultText;
    return "${date.day.toString().padLeft(2, '0')} ${_monthName(date.month)} ${date.year}";
  }

  Future<void> downloadExcel() async {
    setState(() {
      isExcelGenerating = true;
    });
    try {
      if (!await requestStoragePermission()) {
        setState(() {
          isExcelGenerating = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Storage permission denied.")),
        );
        return;
      }

      String getFormattedDate(DateTime date) {
        final h = date.hour % 12 == 0 ? 12 : date.hour % 12;
        final ampm = date.hour < 12 ? "AM" : "PM";
        final min = date.minute.toString().padLeft(2, '0');
        return "${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}-${date.year} ${h.toString().padLeft(2, '0')}:$min $ampm";
      }

      String nowString = getFormattedDate(DateTime.now());
      String exportCompanyName = widget.companyName ?? "Unknown";

      List<Map<String, dynamic>> displayedLedgerList = ledgerList.where((entry) {
        int millis = int.tryParse(entry['ledgerDate']?.toString() ?? "0") ?? 0;
        if (millis == 0) return false;
        DateTime entryDate = DateTime.fromMillisecondsSinceEpoch(millis);
        if (startDate != null && entryDate.isBefore(DateTime(startDate!.year, startDate!.month, startDate!.day))) {
          return false;
        }
        if (endDate != null && entryDate.isAfter(DateTime(endDate!.year, endDate!.month, endDate!.day, 23, 59, 59, 999))) {
          return false;
        }
        return true;
      }).toList();

      displayedLedgerList.sort((a, b) {
        int aDate = int.tryParse(a['ledgerDate']?.toString() ?? "0") ?? 0;
        int bDate = int.tryParse(b['ledgerDate']?.toString() ?? "0") ?? 0;
        return bDate.compareTo(aDate);
      });

      List<Map<String, dynamic>> rows = displayedLedgerList.map((entry) {
        int millis = int.tryParse(entry['ledgerDate']?.toString() ?? "0") ?? 0;
        String ledgerDate;
        if (millis != 0) {
          final d = DateTime.fromMillisecondsSinceEpoch(millis);
          final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
          final ampm = d.hour < 12 ? "AM" : "PM";
          final min = d.minute.toString().padLeft(2, '0');
          ledgerDate = "${d.day.toString().padLeft(2, '0')}-${d.month.toString().padLeft(2, '0')}-${d.year} ${h.toString().padLeft(2, '0')}:$min $ampm";
        } else {
          ledgerDate = "-";
        }
        return {
          "username": entry['username'] ?? "",
          "debitAmount": entry['debitAmount']?.toString() ?? "0.00",
          "creditAmount": entry['creditAmount']?.toString() ?? "0.00",
          "balance": entry['balance']?.toString() ?? "",
          "ledgerDate": ledgerDate
        };
      }).toList();

      final Map<String, String> queryParams = {
        "companyName": exportCompanyName,
        "updateAt": nowString,
        "totelCredit": totals['totalCreditAmount']?.toString() ?? "0.00",
        "totelDebit": totals['totalDebitAmount']?.toString() ?? "0.00",
        "totelBalance": totals['totalBalance']?.toString() ?? "0.00",
        "row": jsonEncode(rows),
      };

      final uri = Uri.http(
        "account.galaxyex.xyz",
        "/v1/user/api/account/generate-excel",
        queryParams,
      );

      final response = await http.get(uri);

      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
        final directory = await getApplicationDocumentsDirectory();
        final filePath = "${directory.path}/report_${DateTime.now().millisecondsSinceEpoch}.xlsx";
        final file = File(filePath);
        await file.writeAsBytes(response.bodyBytes);

        setState(() {
          isExcelGenerating = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Excel downloaded: $filePath")),
        );
        await OpenFile.open(filePath);
      } else {
        setState(() {
          isExcelGenerating = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to download Excel: ${response.statusCode}")),
        );
      }
    } catch (e) {
      setState(() {
        isExcelGenerating = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error downloading Excel: $e")),
      );
    }
  }

  Future<void> downloadPdf() async {
    setState(() {
      isDownloading = true;
    });
    try {
      if (!await requestStoragePermission()) {
        setState(() {
          isDownloading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Storage permission denied.")),
        );
        return;
      }

      String getFormattedDate(DateTime date) {
        final h = date.hour % 12 == 0 ? 12 : date.hour % 12;
        final ampm = date.hour < 12 ? "AM" : "PM";
        final min = date.minute.toString().padLeft(2, '0');
        return "${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}-${date.year} ${h.toString().padLeft(2, '0')}:$min $ampm";
      }

      String nowString = getFormattedDate(DateTime.now());
      String exportCompanyName = widget.companyName ?? "Unknown";

      List<Map<String, dynamic>> displayedLedgerList = ledgerList.where((entry) {
        int millis = int.tryParse(entry['ledgerDate']?.toString() ?? "0") ?? 0;
        if (millis == 0) return false;
        DateTime entryDate = DateTime.fromMillisecondsSinceEpoch(millis);
        if (startDate != null && entryDate.isBefore(DateTime(startDate!.year, startDate!.month, startDate!.day))) {
          return false;
        }
        if (endDate != null && entryDate.isAfter(DateTime(endDate!.year, endDate!.month, endDate!.day, 23, 59, 59, 999))) {
          return false;
        }
        return true;
      }).toList();

      List<Map<String, dynamic>> rows = displayedLedgerList.map((entry) {
        int millis = int.tryParse(entry['ledgerDate']?.toString() ?? "0") ?? 0;
        String ledgerDate;
        if (millis != 0) {
          final d = DateTime.fromMillisecondsSinceEpoch(millis);
          final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
          final ampm = d.hour < 12 ? "AM" : "PM";
          final min = d.minute.toString().padLeft(2, '0');
          ledgerDate = "${d.day.toString().padLeft(2, '0')}-${d.month.toString().padLeft(2, '0')}-${d.year} ${h.toString().padLeft(2, '0')}:$min $ampm";
        } else {
          ledgerDate = "-";
        }
        return {
          "username": entry['username'] ?? "",
          "debitAmount": entry['debitAmount']?.toString() ?? "0.00",
          "creditAmount": entry['creditAmount']?.toString() ?? "0.00",
          "balance": entry['balance']?.toString() ?? "",
          "ledgerDate": ledgerDate
        };
      }).toList();

      final Map<String, String> queryParams = {
        "companyName": exportCompanyName,
        "updateAt": nowString,
        "totelCredit": totals['totalCreditAmount']?.toString() ?? "0.00",
        "totelDebit": totals['totalDebitAmount']?.toString() ?? "0.00",
        "totelBalance": totals['totalBalance']?.toString() ?? "0.00",
        "row": jsonEncode(rows),
      };

      final uri = Uri.http(
        "account.galaxyex.xyz",
        "/v1/user/api/account/generate-pdf",
        queryParams,
      );

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        if (response.bodyBytes.length > 4 &&
            response.bodyBytes[0] == 0x25 &&
            response.bodyBytes[1] == 0x50 &&
            response.bodyBytes[2] == 0x44 &&
            response.bodyBytes[3] == 0x46) {
          final directory = await getApplicationDocumentsDirectory();
          final filePath = '${directory.path}/report_${DateTime.now().millisecondsSinceEpoch}.pdf';
          final file = File(filePath);
          await file.writeAsBytes(response.bodyBytes);
          setState(() {
            isDownloading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("PDF downloaded: $filePath")),
          );
          await OpenFile.open(filePath);
        } else {
          try {
            final Map<String, dynamic> jsonResp = json.decode(response.body);
            if (jsonResp['downloadUrl'] != null) {
              String downloadUrl = jsonResp['downloadUrl'];
              final downloadResponse = await http.get(Uri.parse(downloadUrl));
              if (downloadResponse.statusCode == 200 && downloadResponse.bodyBytes.isNotEmpty) {
                final directory = await getApplicationDocumentsDirectory();
                final filePath = "${directory.path}/report_${DateTime.now().millisecondsSinceEpoch}.pdf";
                final file = File(filePath);
                await file.writeAsBytes(downloadResponse.bodyBytes);

                setState(() {
                  isDownloading = false;
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("PDF downloaded: $filePath")),
                );
                await OpenFile.open(filePath);
              } else {
                setState(() {
                  isDownloading = false;
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Failed to download PDF: ${downloadResponse.statusCode}")),
                );
              }
            } else {
              setState(() {
                isDownloading = false;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("Failed to retrieve PDF download URL.")),
              );
            }
          } catch (e) {
            setState(() {
              isDownloading = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("Failed to parse PDF download response.")),
            );
          }
        }
      } else {
        setState(() {
          isDownloading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to download PDF: ${response.statusCode}")),
        );
      }
    } catch (e) {
      setState(() {
        isDownloading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final giveColor = Colors.red[700]!;
    final getColor = const Color(0xFF205781);

    double totalDebit = double.tryParse(totals['totalDebitAmount']?.toString() ?? "0") ?? 0;
    double totalCredit = double.tryParse(totals['totalCreditAmount']?.toString() ?? "0") ?? 0;
    double balance = double.tryParse(totals['totalBalance']?.toString() ?? "0") ?? 0;
    final balanceColor = balance < 0 ? giveColor : getColor;

    List<Map<String, dynamic>> displayedLedgerList = ledgerList.where((entry) {
      int millis = int.tryParse(entry['ledgerDate']?.toString() ?? "0") ?? 0;
      if (millis == 0) return false;
      DateTime entryDate = DateTime.fromMillisecondsSinceEpoch(millis);
      if (startDate != null && entryDate.isBefore(DateTime(startDate!.year, startDate!.month, startDate!.day))) {
        return false;
      }
      if (endDate != null && entryDate.isAfter(DateTime(endDate!.year, endDate!.month, endDate!.day, 23, 59, 59, 999))) {
        return false;
      }
      return true;
    }).toList();

    displayedLedgerList.sort((a, b) {
      int aDate = int.tryParse(a['ledgerDate']?.toString() ?? "0") ?? 0;
      int bDate = int.tryParse(b['ledgerDate']?.toString() ?? "0") ?? 0;
      return bDate.compareTo(aDate);
    });

    final runningBalancesList = runningBalancesForList(displayedLedgerList);

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
      backgroundColor: const Color(0xFFEAEAEA),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
          ? Center(child: Text(errorMessage!))
          : Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 14, 10, 6),
            child: _singleTopCard(
              debit: totals['totalDebitAmount'],
              credit: totals['totalCreditAmount'],
              balance: totals['totalBalance'],
              giveColor: giveColor,
              getColor: getColor,
              balanceColor: balanceColor,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => _pickDate(isStart: true),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 11, horizontal: 12),
                      decoration: BoxDecoration(
                          color: Color(0xFF205781),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(7),
                            bottomLeft: Radius.circular(7),
                          ),
                          border: Border.all(width: 2,
                              color: Colors.white)
                      ),
                      child: Row(mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.calendar_month,
                            size: 18, color: Colors.white,),
                          SizedBox(width: 7),
                          Text(
                            getDateText(startDate, "START DATE"),
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => _pickDate(isStart: false),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 11, horizontal: 12),
                      decoration: BoxDecoration(
                        color: Color(0xFF205781),
                        borderRadius: const BorderRadius.only(
                          topRight: Radius.circular(7),
                          bottomRight: Radius.circular(7),
                        ),
                        border: Border.all(width: 2,
                            color: Colors.white),
                      ),
                      child: Row(mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.calendar_month,
                              size: 18, color: Colors.white),
                          const SizedBox(width: 7),
                          Text(
                            getDateText(endDate, "END DATE"),
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                              fontSize: 15,
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
          Expanded(
            child: displayedLedgerList.isEmpty
                ? Center(
                child:
                Text(AppStrings.getString("noRecords")))
                : ListView.separated(
              separatorBuilder: (_, __) =>
              const Divider(height: 0),
              itemCount: displayedLedgerList.length,
              itemBuilder: (context, index) {
                final entry = displayedLedgerList[index];
                final username =
                toTitleCase(entry['username'] ?? '');
                final isCredit = double.tryParse(
                    entry['creditAmount'] ?? "0.00")! >
                    0;
                final amount = isCredit
                    ? entry['creditAmount']
                    : entry['debitAmount'];
                final amountNum =
                    double.tryParse(amount?.toString() ?? "0") ??
                        0;

                final amountColor =
                isCredit ? getColor : giveColor;

                final balNum = runningBalancesList[index];
                final runningBalanceProper =
                    balNum != null && balNum.isFinite;

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
                    contentPadding:
                    const EdgeInsets.symmetric(
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
                            AppStrings.getString(
                                "runningBalanceNotProper"),
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
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
        color: Colors.white,
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: Image.asset(
                  "assets/images/pdf.png",
                  width: 20,
                  height: 20,
                  fit: BoxFit.contain,
                  color: null,
                ),
                label: Text(
                  "Download PDF",
                  style: const TextStyle(
                      color: Color(0xFFD32F2F),
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      letterSpacing: 0.3),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFD32F2F)),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(7)),
                ),
                onPressed: isDownloading ? null : downloadPdf,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                icon: Image.asset(
                  "assets/images/excel.png",
                  width: 20,
                  height: 20,
                  fit: BoxFit.contain,
                  color: null,
                ),
                label: const Text(
                  "Download Excel",
                  style: TextStyle(
                      color: Color(0xFF388E3C),
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      letterSpacing: 0.3),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF388E3C)),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(7)),
                ),
                onPressed: isExcelGenerating ? null : downloadExcel,
              ),
            ),
          ],
        ),
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