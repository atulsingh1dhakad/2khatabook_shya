import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../LIST_LANG.dart';

class AddFollowupScreen extends StatefulWidget {
  final VoidCallback? onFollowupAdded;
  final Map<String, dynamic>? followupData;

  const AddFollowupScreen({super.key, this.onFollowupAdded, this.followupData});

  @override
  State<AddFollowupScreen> createState() => _AddFollowupScreenState();
}

class _AddFollowupScreenState extends State<AddFollowupScreen> {
  String? selectedUserId;
  String? selectedUserName;
  List<dynamic> userList = [];
  List<dynamic> filteredUserList = [];
  final _formKey = GlobalKey<FormState>();
  final TextEditingController customerController = TextEditingController();
  final TextEditingController remarkController = TextEditingController();
  bool isSubmitting = false;
  bool isLoadingUsers = true;
  final FocusNode customerFocusNode = FocusNode();

  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  final GlobalKey _fieldKey = GlobalKey();

  bool get isEditing => widget.followupData != null;

  @override
  void initState() {
    super.initState();
    fetchUserList();
    customerController.addListener(_onCustomerTextChanged);
    customerFocusNode.addListener(_handleFocusChange);

    // If editing, pre-fill fields
    if (isEditing) {
      final data = widget.followupData!;
      selectedUserId = data['customerId']?.toString() ?? data['userId']?.toString();
      selectedUserName = data['name'] != null && data['loginId'] != null
          ? "${data['name']} (${data['loginId']})"
          : data['name'] ?? '';
      customerController.text = selectedUserName ?? '';
      remarkController.text = data['remark'] ?? '';
    }
  }

  @override
  void dispose() {
    customerController.removeListener(_onCustomerTextChanged);
    customerFocusNode.removeListener(_handleFocusChange);
    customerController.dispose();
    remarkController.dispose();
    customerFocusNode.dispose();
    _removeOverlay();
    super.dispose();
  }

  void _handleFocusChange() {
    if (customerFocusNode.hasFocus) {
      _showOverlay();
    } else {
      Future.delayed(const Duration(milliseconds: 120), _removeOverlay);
    }
  }

  void _onCustomerTextChanged() {
    final input = customerController.text.toLowerCase();
    setState(() {
      filteredUserList = userList.where((user) {
        final name = (user['name'] ?? '').toString().toLowerCase();
        final loginId = (user['loginId'] ?? '').toString().toLowerCase();
        return name.contains(input) || loginId.contains(input);
      }).toList();
    });
    if (customerFocusNode.hasFocus) {
      _showOverlay();
    }
  }

  void _showOverlay() {
    _removeOverlay();
    if (filteredUserList.isEmpty || !customerFocusNode.hasFocus) return;
    final overlay = Overlay.of(context);
    final overlayBox = overlay?.context.findRenderObject() as RenderBox?;
    final fieldBox = _fieldKey.currentContext?.findRenderObject() as RenderBox?;
    final offset = fieldBox?.localToGlobal(Offset.zero, ancestor: overlayBox) ?? Offset.zero;
    final width = fieldBox?.size.width ?? MediaQuery.of(context).size.width - 32;

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        left: offset.dx,
        top: offset.dy + (fieldBox?.size.height ?? 56),
        width: width,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: Offset(0.0, 0.0), // Already calculated above
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(10),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 650),
              child: ListView.separated(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: filteredUserList.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final user = filteredUserList[index];
                  return ListTile(
                    title: Text("${user['name']} (${user['loginId']})"),
                    subtitle: user['userType'] != null
                        ? Text(user['userType'])
                        : null,
                    onTap: () => _onUserSelected(user),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
    overlay.insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  Future<String?> getAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString("auth_token");
  }

  Future<void> fetchUserList() async {
    setState(() => isLoadingUsers = true);

    final url = "http://account.galaxyex.xyz/v1/user/api/user/get-user";
    final authKey = await getAuthToken();
    if (authKey == null) {
      setState(() => isLoadingUsers = false);
      return;
    }

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
        if (jsonData['meta'] != null && jsonData['meta']['status'] == true) {
          setState(() {
            userList = (jsonData['data'] ?? []).where((user) => !(user['isDelete'] ?? false)).toList();
            filteredUserList = userList;
            isLoadingUsers = false;
          });
        } else {
          setState(() => isLoadingUsers = false);
        }
      } else {
        setState(() => isLoadingUsers = false);
      }
    } catch (e) {
      setState(() => isLoadingUsers = false);
    }
  }

  Future<void> addOrUpdateFollowup() async {
    setState(() => isSubmitting = true);

    final authKey = await getAuthToken();
    if (authKey == null) {
      setState(() => isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.getString("authTokenMissing") ?? "Auth token missing")),
      );
      return;
    }

    try {
      Map<String, dynamic> body = {
        "customerId": selectedUserId,
      };
      if (remarkController.text.trim().isNotEmpty) {
        body["remark"] = remarkController.text.trim();
      }

      Uri url;
      http.Response response;
      Map<String, dynamic> jsonData;

      if (isEditing) {
        // Use update API endpoint
        final id = widget.followupData?['id']?.toString() ?? widget.followupData?['_id']?.toString();
        url = Uri.parse("http://128.199.21.76:3033/api/setting/update-followup/$id");
        response = await http.put(
          url,
          headers: {
            "Authkey": authKey,
            "Content-Type": "application/json",
          },
          body: json.encode(body),
        );
        jsonData = json.decode(response.body);
      } else {
        // Use add API endpoint
        url = Uri.parse("http://128.199.21.76:3033/api/setting/add-followup");
        response = await http.post(
          url,
          headers: {
            "Authkey": authKey,
            "Content-Type": "application/json",
          },
          body: json.encode(body),
        );
        jsonData = json.decode(response.body);
      }

      if ((response.statusCode == 200 || response.statusCode == 201) && jsonData['meta']?['status'] == true) {
        widget.onFollowupAdded?.call();
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(jsonData['meta']?['msg'] ?? (isEditing ? "FollowUp updated successfully" : "FollowUp added successfully"))),
        );
      } else {
        setState(() => isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(jsonData['meta']?['msg'] ?? (isEditing ? "Failed to update follow-up" : "Failed to add follow-up"))),
        );
      }
    } catch (e) {
      setState(() => isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
  }

  void _onUserSelected(dynamic user) {
    setState(() {
      selectedUserId = user['userId'];
      selectedUserName = "${user['name']} (${user['loginId']})";
      customerController.text = selectedUserName!;
    });
    _removeOverlay();
    FocusScope.of(context).requestFocus(FocusNode());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? (AppStrings.getString("editFollowup") ?? "Edit Follow Up") : (AppStrings.getString("addFollowup") ?? "Add Follow Up"), style: const TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF265E85),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: isLoadingUsers
          ? const Center(child: CircularProgressIndicator())
          : GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          FocusScope.of(context).unfocus();
          _removeOverlay();
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                CompositedTransformTarget(
                  link: _layerLink,
                  child: TextFormField(
                    key: _fieldKey,
                    controller: customerController,
                    focusNode: customerFocusNode,
                    readOnly: true, // prevents keyboard from appearing
                    decoration: InputDecoration(
                      labelText: "Select Customer",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      suffixIcon: const Icon(Icons.arrow_drop_down),
                    ),
                    onTap: () {
                      FocusScope.of(context).requestFocus(customerFocusNode); // set focus for overlay logic
                      setState(() {
                        filteredUserList = userList;
                      });
                      _showOverlay();
                    },
                    validator: (_) =>
                    selectedUserId == null ? "Please select a customer" : null,
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: remarkController,
                  decoration: InputDecoration(
                    labelText: AppStrings.getString("remark") ?? "Remark (Optional)",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  // remark is optional
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: isSubmitting
                        ? null
                        : () {
                      if (_formKey.currentState?.validate() ?? false) {
                        addOrUpdateFollowup();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF265E85),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: isSubmitting
                        ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                        : Text(
                      isEditing
                          ? (AppStrings.getString("updateFollowup") ?? "Update Follow Up")
                          : (AppStrings.getString("addFollowup") ?? "Add Follow Up"),
                      style: const TextStyle(color: Colors.white, fontSize: 15),
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
}