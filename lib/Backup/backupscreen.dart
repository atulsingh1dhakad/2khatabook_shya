import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  bool isBackupEnabled = false;
  bool isLoading = false;

  Future<void> toggleBackup(bool value) async {
    setState(() {
      isBackupEnabled = value;
      isLoading = true;
    });

    // Dummy backend call example
    final url = Uri.parse("https://example.com/api/toggle-backup");
    try {
      final response = await http.post(
        url,
        body: {'enabled': value.toString()},
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Backup ${value ? 'enabled' : 'disabled'} successfully!"),
          ),
        );
      } else {
        throw Exception("Failed to update backup status");
      }
    } catch (e) {
      setState(() {
        isBackupEnabled = !value; // revert
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Failed to update backup status: $e"),
        ),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> deleteBackup() async {
    setState(() {
      isLoading = true;
    });

    // Dummy backend call example
    final url = Uri.parse("https://example.com/api/delete-backup");
    try {
      final response = await http.delete(url);

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Backup deleted successfully!"),
          ),
        );
      } else {
        throw Exception("Delete failed");
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Failed to delete backup: $e"),
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
    Color toggleBgColor = isBackupEnabled ? Colors.green : Color(0xff87CEEB).withOpacity(0.5);
    String toggleText = isBackupEnabled ? "Turn Off Backup" : "Turn On Backup";
    Color toggleTextColor = Colors.white;

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: AppBar(
          backgroundColor: const Color(0xFF265E85),
          leading: const BackButton(color: Colors.white),
          elevation: 0,
          title: const Text(
            "Backup & Delete",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
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
                    backgroundColor: Color(0xff2286F7).withOpacity(0.13),
                    child: CircleAvatar(
                      radius: 130,
                      backgroundColor: Color(0xff2286F7).withOpacity(0.08),
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
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Text(
                        "Quick Backup & Restore Cloud Storage",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 22,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        "Easily backup all your Data \n on Cloud Storage",
                        textAlign: TextAlign.center,
                        style: TextStyle(
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
                                offset: Offset(0, 2),
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
                                  padding: const EdgeInsets.symmetric(horizontal: 18),
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
                          onPressed: isLoading ? null : deleteBackup,
                          child: const Text(
                            "Backup and Delete Account",
                            style: TextStyle(
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