import 'dart:convert';
import 'package:Calculator/Backup/backupscreen.dart';
import 'package:Calculator/presentation/currency.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../security/secureform.dart';
import '../testing/fetchstaff.dart';
import 'allcompanytrail.dart';
import 'changepass.dart';
import 'languagescreen.dart';
import 'recyclebinscreen.dart';
import 'loginscreen.dart';
import 'package:http/http.dart' as http;
import '../LIST_LANG.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _version = '';
  String _buildNumber = '';
  String _userName = '';
  String _userType = '';
  String _userId = '';
  bool _accessLoaded = false;
  bool _isViewOnly = false;
  String _selectedLang = "en";

  @override
  void initState() {
    super.initState();
    _loadSelectedLanguage();
    _fetchVersion();
    _fetchUserInfoAndAccess();
  }

  Future<void> _loadSelectedLanguage() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? lang = prefs.getString("app_language");
    setState(() {
      _selectedLang = lang ?? "en";
      AppStrings.setLanguage(_selectedLang);
    });
  }

  Future<void> _changeLanguage(String lang) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString("app_language", lang);
    setState(() {
      _selectedLang = lang;
      AppStrings.setLanguage(lang);
    });
  }

  Future<void> _fetchVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      setState(() {
        _version = info.version;
        _buildNumber = info.buildNumber;
      });
    } catch (e) {
      setState(() {
        _version = 'Unknown';
        _buildNumber = '';
      });
    }
  }

  /// Loads userId/userType from shared_preferences and loads access.
  Future<void> _fetchUserInfoAndAccess() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? userId = prefs.getString("userId");
      String? userType = prefs.getString("userType");
      String? userName = prefs.getString("userName");
      setState(() {
        _userName = userName ?? '';
        _userType = userType ?? '';
        _userId = userId ?? '';
      });
      if (_userId.isNotEmpty) {
        await _fetchUserAccess(_userId);
      } else {
        setState(() {
          _accessLoaded = true;
          _isViewOnly = false;
        });
      }
    } catch (e) {
      setState(() {
        _userName = "";
        _userType = "";
        _userId = "";
        _accessLoaded = true;
        _isViewOnly = false;
      });
    }
  }

  Future<void> _fetchUserAccess(String userId) async {
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
      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = json.decode(response.body);
        final List compDetails = (jsonData['compnayDetails'] ?? []);
        if (compDetails.any((c) => (c['action'] ?? '').toString().toUpperCase() == 'VIEW')) {
          viewOnly = true;
        }
      }
      setState(() {
        _accessLoaded = true;
        _isViewOnly = viewOnly;
      });
    } catch (e) {
      setState(() {
        _accessLoaded = true;
        _isViewOnly = false;
      });
    }
  }

  Future<void> _logout(BuildContext context) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove("auth_token");
    await prefs.remove("userId");
    await prefs.remove("userType");
    await prefs.remove("userName");
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const EmailLoginScreen()),
            (route) => false,
      );
    }
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

  @override
  Widget build(BuildContext context) {
    // Always use the latest language
    AppStrings.setLanguage(_selectedLang);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FA),
      body: Column(
        children: [
          Container(
            decoration: const BoxDecoration(
              color: Color(0xFF205781),
              borderRadius: BorderRadius.only(
                topRight: Radius.circular(18),
              ),
            ),
            width: double.infinity,
            padding: const EdgeInsets.only(top: 36, bottom: 16),
            child: Column(
              children: [
                const CircleAvatar(
                  radius: 34,
                  backgroundColor: Colors.white,
                  child: Icon(Icons.person, color: Color(0xFF205781), size: 38),
                ),
                const SizedBox(height: 10),
                Text(
                  _userName.isNotEmpty ? _userName : "",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  SidebarButton(
                    icon: Icons.arrow_back,
                    label: AppStrings.getString("back"),
                    onTap: null, // default pop by InkWell
                    isBack: true,
                  ),
                  SidebarButton(
                    icon: Icons.all_inbox,
                    label: AppStrings.getString("allCompanyTrial"),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const AllCompanyTrialScreen()),
                      );
                    },
                  ),
                  if (_userType.trim().toUpperCase() != "STAFF")
                    SidebarButton(
                      icon: Icons.group,
                      label: AppStrings.getString("staffList"),
                      onTap: () {
                        if ((_userType.trim().toUpperCase() == "STAFF") && (_isViewOnly || !_accessLoaded)) {
                          _showNoPermissionDialog();
                          return;
                        }
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const StaffListPage()),
                        );
                      },
                    ),
                  SidebarButton(
                    icon: Icons.delete_outline,
                    label: AppStrings.getString("recycleBin"),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const RecycleBinScreen()),
                      );
                    },
                  ),
                  SidebarButton(
                    icon: Icons.language,
                    label: AppStrings.getString("changeLanguage"),
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => LanguagesScreen(
                            onLanguageChanged: (lang) async {
                              await _changeLanguage(lang);
                            },
                          ),
                        ),
                      );
                      await _loadSelectedLanguage();
                      setState(() {}); // to force rebuild with new language
                    },
                  ),
                  SidebarButton(
                    icon: Icons.attach_money,
                    label: AppStrings.getString("currencySetting"),
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => CurrencySettings(),));
                    },
                  ),
                  SidebarButton(
                    icon: Icons.backup_outlined,
                    label: AppStrings.getString("backupAndDelete"),
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => BackupScreen(),));
                    },
                  ),
                  SidebarButton(
                    icon: Icons.security,
                    label: AppStrings.getString("security"),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const SecurityPinScreen()),
                      );
                    },
                  ),
                  SidebarButton(
                    icon: Icons.password,
                    label: AppStrings.getString("changePassword"),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const ChangePass()),
                      );
                    },
                  ),
                  const SizedBox(height: 18),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
                    child: Align(
                      alignment: Alignment.center,
                      child: Text(
                        (_version.isNotEmpty)
                            ? '${AppStrings.getString("appVersion")}: $_version ($_buildNumber)'
                            : '${AppStrings.getString("appVersion")}: ...',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: GestureDetector(
              onTap: () => _logout(context),
              child: Container(
                height: 54,
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  border: Border.all(color: Colors.red.shade300, width: 1.4),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.logout, color: Colors.red, size: 24),
                    const SizedBox(width: 14),
                    Text(
                      AppStrings.getString("logout"),
                      style: const TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.w600,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SidebarButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool isLogout;
  final bool isBack;

  const SidebarButton({
    Key? key,
    required this.icon,
    required this.label,
    this.onTap,
    this.isLogout = false,
    this.isBack = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final color = isLogout ? Colors.red : const Color(0xFF205781);
    final bgColor = isBack
        ? const Color(0xFFE8F1FA)
        : (isLogout ? Colors.red.shade50 : Colors.white);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(9),
        onTap: onTap ?? () => Navigator.of(context).pop(),
        child: Container(
          height: 47,
          decoration: BoxDecoration(
            color: bgColor,
            border: Border.all(color: color, width: 1.3),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Row(
            children: [
              const SizedBox(width: 12),
              Icon(icon, color: color),
              const SizedBox(width: 18),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: 17,
                    fontWeight: isLogout ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ),
              if (!isBack)
                const Icon(Icons.arrow_forward_ios, size: 18, color: Colors.grey),
              const SizedBox(width: 8),
            ],
          ),
        ),
      ),
    );
  }
}