import 'dart:async';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'calculatorpanel.dart';

class YouWillGetPage extends StatefulWidget {
  final String accountId;
  final String accountName;
  final String companyId;

  final String? ledgerId;
  final double? editCredit;
  final String? editRemark;
  final DateTime? editDate;

  const YouWillGetPage({
    Key? key,
    required this.accountId,
    required this.accountName,
    required this.companyId,
    this.ledgerId,
    this.editCredit,
    this.editRemark,
    this.editDate,
  }) : super(key: key);

  @override
  _YouWillGetPageState createState() => _YouWillGetPageState();
}

class _YouWillGetPageState extends State<YouWillGetPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _remarkController;
  late DateTime _selectedDate;
  bool _isLoading = false;

  // For multiple new files
  List<File> _pickedFiles = [];
  // For existing files (when editing)
  List<String> _existingFiles = [];
  Set<String> _removedFiles = {};

  // Calculator state
  String _calcRawInput = "";
  String _calcDisplay = "";
  double? _amountValue;

  // Blinking cursor state
  bool _showCursor = true;
  Timer? _cursorTimer;

  // Focus management
  bool _isAmountFocused = false; // Initially not focused
  late FocusNode _remarkFocusNode;

  @override
  void initState() {
    super.initState();
    _amountValue = widget.editCredit;
    _calcRawInput = widget.editCredit != null ? widget.editCredit!.toString() : "";
    _calcDisplay = widget.editCredit != null ? "${widget.editCredit} = ${widget.editCredit}" : "";
    _remarkController = TextEditingController(text: widget.editRemark ?? "");
    _selectedDate = widget.editDate ?? DateTime.now();

    _remarkFocusNode = FocusNode();
    _remarkFocusNode.addListener(_onRemarkFocusChange);

    if (widget.ledgerId != null) {
      // If editing, fetch existing files
      fetchExistingFiles();
    }

    _startCursorTimer();
  }

  Future<void> fetchExistingFiles() async {
    // This assumes your backend returns ledger details with a list of file URLs under 'path'
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
      request.fields["entryType"] = "get";
      request.fields["companyId"] = widget.companyId;
      request.fields["accountId"] = widget.accountId;
      request.fields["date"] = isoDate;

      // Add new files
      for (final file in _pickedFiles) {
        request.files.add(await http.MultipartFile.fromPath("bill", file.path));
      }

      // If editing, tell backend which files to remove
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
      allowMultiple: false,
    );
    if (result != null && result.files.single.path != null) {
      setState(() {
        _pickedFiles.add(File(result.files.single.path!));
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("File attached: ${result.files.single.name}")),
      );
    }
  }

  Widget _buildFilePreview() {
    final imageExts = ['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp'];
    final filesPresent = _pickedFiles.isNotEmpty || _existingFiles.any((f) => !_removedFiles.contains(f));
    if (!filesPresent) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Existing files (from server)
        ..._existingFiles.where((f) => !_removedFiles.contains(f)).map((url) {
          final ext = url.split('.').last.toLowerCase();
          final isImage = imageExts.contains(ext);
          return Padding(
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
                          child: Image.network(url, fit: BoxFit.contain),
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
                            isImage ? "Attached Image" : "Attached File",
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
          );
        }),
        // New picked files
        ..._pickedFiles.asMap().entries.map((entry) {
          final i = entry.key;
          final file = entry.value;
          final ext = file.path.split('.').last.toLowerCase();
          final isImage = imageExts.contains(ext);
          return Padding(
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
          );
        }),
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Row(
            children: [
              ElevatedButton.icon(
                onPressed: _onAttachFile,
                icon: const Icon(Icons.attach_file, size: 18),
                label: const Text("Attach More"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                "You can add/remove multiple files",
                style: TextStyle(fontSize: 13, color: Colors.grey),
              )
            ],
          ),
        ),
      ],
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
            widget.ledgerId != null ? 'Edit Entry (You Will Get)' : 'You Will Get From ${widget.accountName}',
            style: const TextStyle(fontSize: 15, color: Colors.white)),
        backgroundColor: const Color(0xFF5D8D4B),
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
                      color: Colors.green.shade50,
                      border: Border.all(color: Colors.green.shade200),
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
                                    color: Colors.green)),
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
                                      color: Colors.green,
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
                                        color: Colors.green,
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
                decoration: const InputDecoration(
                  hintText: 'Remark',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
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
                  // The attach button is now in file preview section
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
              accentColor: Colors.green,
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
                    : Text(widget.ledgerId != null ? 'Update' : 'Save', style: const TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF5D8D4B),
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