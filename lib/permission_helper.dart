import 'dart:io';
import 'package:permission_handler/permission_handler.dart';

Future<bool> requestStoragePermission() async {
  if (!Platform.isAndroid) return true;

  final sdkInt = await _getAndroidSdkInt();
  if (sdkInt >= 30) {
    // Android 11+ requires MANAGE_EXTERNAL_STORAGE
    var status = await Permission.manageExternalStorage.status;
    if (!status.isGranted) {
      status = await Permission.manageExternalStorage.request();
      if (!status.isGranted) {
        // Optionally open app settings for user to manually grant
        await openAppSettings();
        return false;
      }
    }
    return true;
  } else {
    // Android 10 and below
    var status = await Permission.storage.status;
    if (!status.isGranted) {
      status = await Permission.storage.request();
      if (!status.isGranted) return false;
    }
    return true;
  }
}

// Helper to get Android SDK version
Future<int> _getAndroidSdkInt() async {
  try {
    // device_info_plus is recommended for production code, but hardcoded for brevity here
    // import 'package:device_info_plus/device_info_plus.dart';
    // var androidInfo = await DeviceInfoPlugin().androidInfo;
    // return androidInfo.version.sdkInt;
    return 34; // <= You may set accordingly or use package as above
  } catch (_) {
    return 30;
  }
}