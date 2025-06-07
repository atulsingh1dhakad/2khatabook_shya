import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;

class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  String? gdBackupKey;
  GoogleSignInAccount? _account;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId:
    "955712361763-3hg2cfucc523rqp6j8dapqnsfvb55fn7.apps.googleusercontent.com",
    scopes: [
      drive.DriveApi.driveFileScope,
      drive.DriveApi.driveAppdataScope,
    ],
  );

  Future<void> connectGoogleDrive() async {
    try {
      final account = await _googleSignIn.signIn();
      if (account == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Google Drive sign-in cancelled.")),
        );
        return;
      }

      final auth = await account.authentication;
      setState(() {
        gdBackupKey = auth.accessToken;
        _account = account;
      });

      final client = GoogleHttpClient(auth.accessToken!);
      final driveApi = drive.DriveApi(client);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Connected to Google Drive!")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Google Drive sign-in failed: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
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
        child: Column(
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
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xff2286F7),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                      onPressed: connectGoogleDrive,
                      child: const Text(
                        "Connect Google Drive",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  if (gdBackupKey != null) ...[
                    const SizedBox(height: 18),
                    Text(
                      "Access Token: $gdBackupKey",
                      style: const TextStyle(fontSize: 12, color: Colors.green),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class GoogleHttpClient extends http.BaseClient {
  final String _accessToken;
  final http.Client _client = http.Client();

  GoogleHttpClient(this._accessToken);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers['Authorization'] = 'Bearer $_accessToken';
    return _client.send(request);
  }

  @override
  void close() {
    _client.close();
    super.close();
  }
}
