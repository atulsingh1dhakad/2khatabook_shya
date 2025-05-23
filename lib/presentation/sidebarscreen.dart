import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shya_khatabook/presentation/changepass.dart';
import 'package:shya_khatabook/presentation/staffscreen.dart';

import 'loginscreen.dart';

// Dummy LoginScreen for demonstration. Replace with your actual login screen import.

class settingscreen extends StatefulWidget {
  const settingscreen({super.key});

  @override
  State<settingscreen> createState() => _settingscreenState();
}

class _settingscreenState extends State<settingscreen> {
  Future<void> _logout(BuildContext context) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove("auth_token");
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => EmailLoginScreen(),),
            (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FA),
      body: SafeArea(
        child: Column(
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
                children: const [
                  CircleAvatar(
                    radius: 34,
                    backgroundColor: Colors.white,
                    child: Icon(Icons.person, color: Color(0xFF205781), size: 38),
                  ),
                  SizedBox(height: 10),
                  Text(
                    "GGM 1",
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold),
                  )
                ],
              ),
            ),
            const SizedBox(height: 18),
            SidebarButton(
              icon: Icons.arrow_back,
              label: "Back",
              onTap: null, // default pop by InkWell
              isBack: true,
            ),
            SidebarButton(
              icon: Icons.all_inbox,
              label: "All Company Trial",
              onTap: () {},
            ),
            SidebarButton(
              icon: Icons.group,
              label: "Staff List",
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => StaffScreen()),
                );
              },
            ),
            SidebarButton(
              icon: Icons.delete_outline,
              label: "Recycle Bin",
              onTap: () {},
            ),
            SidebarButton(
              icon: Icons.language,
              label: "Change Language",
              onTap: () {},
            ),
            SidebarButton(
              icon: Icons.attach_money,
              label: "Currency Settings",
              onTap: () {},
            ),
            SidebarButton(
              icon: Icons.backup_outlined,
              label: "Backup Settings",
              onTap: () {},
            ),
            SidebarButton(
              icon: Icons.password,
              label: "Change Password",
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => ChangePass()),
                );
              },
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: GestureDetector(
                onTap: () => _logout(context),
                child: Container(
                  height: 54,
                  decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      border: Border.all(color: Colors.red.shade300, width: 1.4),
                      borderRadius: BorderRadius.circular(9)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.logout, color: Colors.red, size: 24),
                      SizedBox(width: 14),
                      Text("Logout",
                          style: TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.w600,
                            fontSize: 18,
                          )),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
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
              // Only show the forward arrow if NOT the back button
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