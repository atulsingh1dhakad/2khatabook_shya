import 'dart:async';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../LIST_LANG.dart';
import 'calculatorpanel.dart';

class YouWillGivePage extends StatefulWidget {
  final String accountId;
  final String accountName;
  final String companyId;

  final String? ledgerId;
  final double? editDebit;
  final String? editRemark;
  final DateTime? editDate;

  const YouWillGivePage({
    Key? key,
    required this.accountId,
    required this.accountName,
    required this.companyId,
    this.ledgerId,
    this.editDebit,
    this.editRemark,
    this.editDate,
  }) : super(key: key);

  @override
  _YouWillGivePageState createState() => _YouWillGivePageState();
}

class _YouWillGivePageState extends State<YouWillGivePage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _remarkController;
  late DateTime _selectedDate;
  bool _isLoading = false;

  List<File> _pickedFiles = [];
  List<String> _existingFiles = [];
  Set<String> _removedFiles = {};

  String _calcRawInput = "";
  String _calcDisplay = "";
  double? _amountValue;

  bool _showCursor = true;
  Timer? _cursorTimer;
  bool _isAmountFocused = false;
  late FocusNode _remarkFocusNode;

  @override
  void initState() {
    super.initState();
    _amountValue = widget.editDebit;
    _calcRawInput = widget.editDebit != null ? widget.editDebit!.toString() : "";
    _calcDisplay = widget.editDebit != null ? "${widget.editDebit} = ${widget.editDebit}" : "";
    _remarkController = TextEditingController(text: widget.editRemark ?? "");
    _selectedDate = widget.editDate ?? DateTime.now();

    _remarkFocusNode = FocusNode();
    _remarkFocusNode.addListener(_onRemarkFocusChange);

    if (widget.ledgerId != null) {
      fetchExistingFiles();
    }

    _startCursorTimer();
  }

  Future<void> fetchExistingFiles() async {
    final prefs = await SharedPreferences.getInstance();
    final authKey = prefs.getString("auth_token");
    if (authKey == null) return;

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
        if (entry != null) {
          dynamic path = entry['path'];
          if (path is String && path.isNotEmpty) {
            setState(() {
              _existingFiles = [path];
            });
          } else if (path is List) {
            setState(() {
              _existingFiles = List<String>.from(path.whereType<String>());
            });
          }
        }
      }
    }
  }

  void _onRemarkFocusChange() {
    if (_remarkFocusNode.hasFocus) {
      setState(() {
        _isAmountFocused = false;
      });
    }
  }

  void _onAmountTap() {
    if (!_isAmountFocused) {
      setState(() {
        _isAmountFocused = true;
      });
      _remarkFocusNode.unfocus();
      FocusScope.of(context).unfocus();
    }
  }

  void _startCursorTimer() {
    _cursorTimer?.cancel();
    _cursorTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (_isAmountFocused) {
        setState(() {
          _showCursor = !_showCursor;
        });
      } else {
        setState(() {
          _showCursor = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _cursorTimer?.cancel();
    _remarkFocusNode.dispose();
    _remarkController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  String get formattedDate {
    final months = [
      'jan', 'feb', 'mar', 'apr', 'may', 'jun',
      'jul', 'aug', 'sep', 'oct', 'nov', 'dec'
    ];
    return "${_selectedDate.day.toString().padLeft(2, '0')}-"
        "${months[_selectedDate.month - 1]}-"
        "${_selectedDate.year}";
  }

  String get isoDate =>
      "${_selectedDate.year.toString().padLeft(4, '0')}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}";

  /// Download a file from a URL and return it as a File.
  Future<File> urlToFile(String imageUrl, String filename) async {
    final tempDir = await Directory.systemTemp.createTemp();
    final file = File('${tempDir.path}/$filename');
    final response = await http.get(Uri.parse(imageUrl));
    await file.writeAsBytes(response.bodyBytes);
    return file;
  }

  Future<void> _saveData() async {
    if (_amountValue == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Enter a valid amount")),
      );
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final prefs = await SharedPreferences.getInstance();
    final authKey = prefs.getString("auth_token");
    final amount = _amountValue ?? 0;

    final url = Uri.parse('http://account.galaxyex.xyz/v1/user/api/account/add-ledger');

    try {
      var request = http.MultipartRequest('POST', url);

      request.headers.addAll({
        "Content-Type": "application/json",
        "Authkey": authKey ?? "",
      });

      if (widget.ledgerId != null) request.fields["ledgerId"] = widget.ledgerId!;
      request.fields["amount"] = amount.toString();
      request.fields["remark"] = _remarkController.text.trim();
      request.fields["entryType"] = "give";
      request.fields["companyId"] = widget.companyId;
      request.fields["accountId"] = widget.accountId;
      request.fields["date"] = isoDate;

      // 1. Download and attach all existing files (that are not removed) as File objects
      for (final url in _existingFiles.where((f) => !_removedFiles.contains(f))) {
        final filename = url.split('/').last;
        try {
          final file = await urlToFile(url, filename);
          request.files.add(await http.MultipartFile.fromPath("bill", file.path));
        } catch (e) {
          // Optionally show an error or skip file
        }
      }

      // 2. Attach all newly picked files
      for (final file in _pickedFiles) {
        request.files.add(await http.MultipartFile.fromPath("bill", file.path));
      }

      // 3. If editing, tell backend which files to remove
      if (widget.ledgerId != null) {
        request.fields["removeAttachments"] = jsonEncode(_removedFiles.toList());
      }

      final response = await request.send();

      final respStr = await response.stream.bytesToString();
      final Map<String, dynamic> jsonResp = json.decode(respStr);

      if (response.statusCode == 200 && jsonResp['meta'] != null && jsonResp['meta']['status'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(widget.ledgerId != null ? "Updated successfully!" : "Saved successfully!")));
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(jsonResp['meta']?['msg'] ?? "Failed to save (API error)")));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _onAttachFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: true,
    );
    if (result != null) {
      setState(() {
        // Don't add duplicates
        for (var f in result.files) {
          if (f.path != null && !_pickedFiles.any((file) => file.path == f.path)) {
            _pickedFiles.add(File(f.path!));
          }
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("${result.files.length} file(s) attached")),
      );
    }

  }

  Widget _buildFilePreview() {
    final imageExts = ['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp'];
    List<Widget> previews = [];

    // Existing files (edit mode)
    for (final url in _existingFiles.where((f) => !_removedFiles.contains(f))) {
      final ext = url.split('.').last.toLowerCase();
      final isImage = imageExts.contains(ext);
      previews.add(
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              border: Border.all(color: Colors.grey.shade300, width: 1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                if (isImage)
                  GestureDetector(
                    onTap: () => showDialog(
                      context: context,
                      builder: (_) => Dialog(
                        child: Image.network(
                          url,
                          fit: BoxFit.contain,
                          errorBuilder: (ctx, err, stack) =>
                          const Padding(
                            padding: EdgeInsets.all(18.0),
                            child: Icon(Icons.broken_image, size: 60),
                          ),
                        ),
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(10), bottomLeft: Radius.circular(10)),
                      child: Image.network(
                        url,
                        height: 75,
                        width: 75,
                        fit: BoxFit.cover,
                        errorBuilder: (ctx, err, stack) =>
                        const Icon(Icons.broken_image, size: 40),
                      ),
                    ),
                  )
                else
                  Container(
                    margin: const EdgeInsets.only(left: 14, right: 14),
                    child: const Icon(Icons.insert_drive_file, color: Colors.blueAccent, size: 38),
                  ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isImage ? AppStrings.getString("photoAttachments") : "Attached File",
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          url.split('/').last,
                          style: const TextStyle(fontSize: 13, color: Colors.black54),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20, color: Colors.grey),
                  onPressed: () {
                    setState(() {
                      _removedFiles.add(url);
                    });
                  },
                  tooltip: "Remove attachment",
                ),
              ],
            ),
          ),
        ),
      );
    }

    // New picked files (create or edit mode)
    for (var i = 0; i < _pickedFiles.length; i++) {
      final file = _pickedFiles[i];
      final ext = file.path.split('.').last.toLowerCase();
      final isImage = imageExts.contains(ext);
      previews.add(
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              border: Border.all(color: Colors.grey.shade300, width: 1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                if (isImage)
                  ClipRRect(
                    borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(10), bottomLeft: Radius.circular(10)),
                    child: Image.file(
                      file,
                      height: 75,
                      width: 75,
                      fit: BoxFit.cover,
                    ),
                  )
                else
                  Container(
                    margin: const EdgeInsets.only(left: 14, right: 14),
                    child: const Icon(Icons.insert_drive_file, color: Colors.blueAccent, size: 38),
                  ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isImage ? "Attached Image" : "Attached File",
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          file.path.split('/').last,
                          style: const TextStyle(fontSize: 13, color: Colors.black54),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20, color: Colors.grey),
                  onPressed: () {
                    setState(() {
                      _pickedFiles.removeAt(i);
                    });
                  },
                  tooltip: "Remove attachment",
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: previews,
    );
  }

  void _onCalculatorChanged(String input, String preview, double? value) {
    setState(() {
      _calcRawInput = input;
      _calcDisplay = preview;
      _amountValue = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool showPreview = _calcRawInput.isNotEmpty &&
        _calcDisplay.isNotEmpty &&
        (
            RegExp(r'[+\-*/×÷]').hasMatch(_calcRawInput) ||
                RegExp(r'[+\-*/×÷%]$').hasMatch(_calcRawInput)
        );

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        leading: const BackButton(color: Colors.white,),
        title: Text(
            widget.ledgerId != null ? AppStrings.getString("editEntry") : AppStrings.getString("youWillGiveTo"),
            style: const TextStyle(fontSize: 15, color: Colors.white)),
        backgroundColor: const Color(0xffc96868),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(10),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              GestureDetector(
                onTap: _onAmountTap,
                child: AnimatedSize(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.ease,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      border: Border.all(color: Colors.red.shade200),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const Text("₹ ",
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 22,
                                    color: Colors.red)),
                            Expanded(
                              child: Row(
                                children: [
                                  Text(
                                    _calcRawInput.isEmpty
                                        ? ""
                                        : _calcRawInput,
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.red,
                                    ),
                                  ),
                                  if (_isAmountFocused && _showCursor)
                                    AnimatedOpacity(
                                      opacity: 1,
                                      duration: const Duration(milliseconds: 200),
                                      child: Container(
                                        width: 2,
                                        height: 26,
                                        margin: const EdgeInsets.only(left: 2),
                                        color: Colors.red,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (showPreview)
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0, left: 3),
                            child: Text(
                              _calcDisplay,
                              style: const TextStyle(
                                  fontSize: 16,
                                  color: Colors.black54,
                                  fontWeight: FontWeight.w500),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _remarkController,
                focusNode: _remarkFocusNode,
                decoration: InputDecoration(
                  hintText: AppStrings.getString("remark"),
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                ),
                onTap: () {
                  setState(() {
                    _isAmountFocused = false;
                  });
                },
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 40,
                      child: InkWell(
                        onTap: _pickDate,
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  formattedDate,
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                              const Icon(Icons.calendar_today, size: 16),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SizedBox(
                      height: 40,
                      child: OutlinedButton.icon(
                        onPressed: _onAttachFile,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          side: const BorderSide(),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(7),
                          ),
                        ),
                        icon: const Icon(Icons.camera_alt, size: 18, color: Colors.black,),
                        label: Text(
                          _pickedFiles.isEmpty
                              ? AppStrings.getString("photoAttachments")
                              : "Files: ${_pickedFiles.length}",
                          style: const TextStyle(fontSize: 13, color: Colors.grey),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              _buildFilePreview(),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_isAmountFocused)
            CalculatorPanel(
              initialInput: _calcRawInput,
              accentColor: Colors.red,
              onChanged: _onCalculatorChanged,
              onDone: () {},
            ),
          Padding(
            padding: const EdgeInsets.all(15.0),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveData,
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(widget.ledgerId != null ? AppStrings.getString("update") : AppStrings.getString("save"), style: const TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xffc96868),
                  shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
                  elevation: 5,
                  padding: const EdgeInsets.all(2),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}