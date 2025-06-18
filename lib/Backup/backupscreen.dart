import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

import '../LIST_LANG.dart';
import '../presentation/loginscreen.dart';

class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  bool isBackupEnabled = false;
  bool isLoading = false;
  String _selectedLang = "en";
  String? _userId;

  @override
  void initState() {
    super.initState();
    _loadSelectedLanguage();
    _loadUserId();
  }

  Future<void> _loadSelectedLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    final lang = prefs.getString("app_language") ?? "en";
    setState(() {
      _selectedLang = lang;
      AppStrings.setLanguage(_selectedLang);
    });
  }

  Future<void> _loadUserId() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userId = prefs.getString("userId");
    });
  }

  Future<String?> getAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString("auth_token");
  }

  Future<void> toggleBackup(bool value) async {
    setState(() {
      isBackupEnabled = value;
      isLoading = true;
    });

    // Dummy backend call example (not implemented)
    await Future.delayed(const Duration(seconds: 1));
    setState(() {
      isLoading = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          value
              ? AppStrings.getString("turnOnBackup") + "!"
              : AppStrings.getString("turnOnBackup") +
              " " +
              AppStrings.getString("cancel") +
              "!",
        ),
      ),
    );
  }

  Future<void> confirmAndDeleteBackup() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppStrings.getString("confirmDeleteBackup")),
        content: Text(
          AppStrings.getString("deleteBackupWarning") +
              "\n\n" +
              AppStrings.getString("areYouSure"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(AppStrings.getString("cancel")),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              AppStrings.getString("delete"),
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await deleteBackup();
    }
  }

  Future<void> deleteBackup() async {
    setState(() {
      isLoading = true;
    });

    final prefs = await SharedPreferences.getInstance();
    final authToken = prefs.getString("auth_token") ?? "";
    final userId = _userId;

    if (userId == null || userId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppStrings.getString("userId") +
              " " +
              AppStrings.getString("notFound")),
        ),
      );
      setState(() {
        isLoading = false;
      });
      return;
    }

    final url = Uri.parse("http://account.galaxyex.xyz/v1/user/api/user/backup-and-delete/$userId");
    try {
      final response = await http.get(
        url,
        headers: {
          "Authkey": authToken,
          "Content-Type": "application/json",
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data["meta"]?["status"] == true) {
          // Clear all tokens and user info
          await prefs.remove("auth_token");
          await prefs.remove("userId");
          await prefs.remove("userType");
          await prefs.remove("userName");
          await prefs.remove("security_enabled");
          await prefs.remove("app_language");
          // ... add more if you store more sensitive data

          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                AppStrings.getString("backupAndDeleteAccount") +
                    " " +
                    AppStrings.getString("delete"),
              ),
            ),
          );
          // Go to login screen
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const EmailLoginScreen()),
                (route) => false,
          );
        } else {
          final msg = data["meta"]?["msg"] ?? AppStrings.getString("delete") + " " + AppStrings.getString("failed");
          throw Exception(msg);
        }
      } else {
        throw Exception(AppStrings.getString("delete") +
            " " +
            AppStrings.getString("failed"));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("${AppStrings.getString("failedToDeleteBackup")}: $e"),
        ),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    AppStrings.setLanguage(_selectedLang);

    Color toggleBgColor =
    isBackupEnabled ? Colors.green : const Color(0xff87CEEB).withOpacity(0.5);
    String toggleText = isBackupEnabled
        ? AppStrings.getString("turnOnBackup") +
        " " +
        AppStrings.getString("cancel")
        : AppStrings.getString("turnOnBackup");
    Color toggleTextColor = Colors.white;

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: AppBar(
          backgroundColor: const Color(0xFF265E85),
          leading: const BackButton(color: Colors.white),
          elevation: 0,
          title: Text(
            AppStrings.getString("backupAndDelete"),
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w500),
          ),
          centerTitle: true,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(22)),
          ),
        ),
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 50),
                Center(
                  child: CircleAvatar(
                    radius: 150,
                    backgroundColor:
                    const Color(0xff2286F7).withOpacity(0.13),
                    child: CircleAvatar(
                      radius: 130,
                      backgroundColor:
                      const Color(0xff2286F7).withOpacity(0.08),
                      child: Center(
                        child: Image.asset(
                          'assets/images/backup.png',
                          width: 240,
                          height: 240,
                        ),
                      ),
                    ),
                  ),
                ),
                const Spacer(),
                Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: Color(0xFF225B84),
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(32),
                    ),
                  ),
                  padding:
                  const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        AppStrings.getString("quickBackupRestore"),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 22,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        AppStrings.getString("easilyBackupData"),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 15,
                          color: Colors.white,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      const SizedBox(height: 28),
                      // Custom Toggle Button
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          decoration: BoxDecoration(
                            color: toggleBgColor,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.08),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: InkWell(
                            onTap: isLoading
                                ? null
                                : () => toggleBackup(!isBackupEnabled),
                            borderRadius: BorderRadius.circular(24),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 18),
                                  child: Text(
                                    toggleText,
                                    style: TextStyle(
                                      color: toggleTextColor,
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.only(right: 18),
                                  child: Switch(
                                    value: isBackupEnabled,
                                    onChanged: isLoading
                                        ? null
                                        : (val) => toggleBackup(val),
                                    activeColor: Colors.white,
                                    inactiveThumbColor: Colors.white,
                                    activeTrackColor: Colors.green,
                                    inactiveTrackColor: Colors.red,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Delete Backup Button
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                          ),
                          onPressed:
                          isLoading ? null : confirmAndDeleteBackup,
                          child: Text(
                            AppStrings.getString("backupAndDeleteAccount"),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (isLoading)
              Container(
                color: Colors.black26,
                child: const Center(
                  child: CircularProgressIndicator(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}