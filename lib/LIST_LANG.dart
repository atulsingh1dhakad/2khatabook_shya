/// Provides localized strings for the app, supporting both English and Hindi.
/// Call [AppStrings.setLanguage("en")] or [AppStrings.setLanguage("hi")] as needed.
/// To load from backend, call [AppStrings.loadFromBackend(json)].
class AppStrings {
  static AppStrings? _instance;
  late String currentLang;
  late Map<String, String> _translations;

  AppStrings._(this.currentLang, this._translations);

  /// Set language to "en" or "hi" (default: English)
  static void setLanguage(String lang) {
    if (lang == "hi") {
      _instance = AppStrings._(lang, _hindi);
    } else {
      _instance = AppStrings._("en", _english);
    }
  }

  /// Load from backend map: expects backend response JSON.
  static void loadFromBackend(Map<String, dynamic> json) {
    String lang = json['lang'] ?? 'en';
    Map<String, dynamic> tr = json['translations'] ?? {};
    Map<String, String> translations = {};
    tr.forEach((key, value) {
      translations[key] = value.toString();
    });
    _instance = AppStrings._(lang, translations);
  }

  static AppStrings get instance {
    if (_instance == null) {
      throw Exception("AppStrings is not initialized. Call setLanguage or loadFromBackend first.");
    }
    return _instance!;
  }

  /// Returns the localized string for the provided key.
  String get(String key) => _translations[key] ?? key;

  /// Static helper for one-line access.
  static String getString(String key) => instance.get(key);

  /// Returns the language code ("en" or "hi")
  String get lang => currentLang;

  // --- English Strings (default) ---
  static const Map<String, String> _english = {
    "addCustomer": "Add Customer",
    "searchCustomer": "Search Customer",
    "youWillGet": "You Will Get",
    "youWillGive": "You Will Give",
    "balance": "Balance",
    "getReport": "Get Report",
    "addNewCompany": "Add New Company",
    "addCompany": "Add Company",
    "companyName": "Company Name",
    "updateCompany": "Update Company",
    "back": "Back",
    "downloadReport": "Download Report",
    "youGive": "You Give",
    "youGet": "You Get",
    "updateCustomer": "Update Customer",
    "delete": "Delete",
    "share": "Share",
    "entryDetails": "Entry Details",
    "editEntry": "Edit Entry",
    "safeAndSecure": "Safe And Secure",
    "runningBalance": "Running Balance",
    "save": "Save",
    "youWillGetFrom": "You Will Get From",
    "youWillGiveTo": "You Will Give To",
    "logout": "Logout",
    "changePassword": "Change Password",
    "currentPassword": "Current Password",
    "newPassword": "New Password",
    "confirmNewPassword": "Confirm New Password",
    "update": "Update",
    "cancel": "Cancel",
    "backupAndDelete": "Backup & Delete",
    "currencySetting": "Currency Setting",
    "changeLanguage": "Change Language",
    "recycleBin": "Recycle Bin",
    "staffList": "Staff List",
    "allCompanyTrial": "All Company Trial",
    "addNewStaff": "Add New Staff",
    "updateStaff": "Update Staff",
    "selectCompaniesAndActions": "Select Companies & Actions",
    "undo": "Undo",
    "name": "Name",
    "password": "Password",
    "userId": "UserID",
    "customerName": "Customer Name",
    "remark": "Remark",
    "photoAttachments": "Photo Attachments",
    "close": "Close",
    "edit": "Edit",
    "userType": "User Type",
    "allLanguages": "All Languages",
    "saveSetting": "Save Setting",
    "selectedLanguage": "Selected Language",
    "backupAndDeleteAccount": "Backup And Delete Account",
    "cloudStorage": "Cloud Storage",
    "easilyBackupData": "Easily Backup All Your Data On Cloud Storage",
    "quickBackupRestore": "Quick Backup & Restore",
    "turnOnBackup": "Turn On Backup",
    "settledUp": "Settled Up", // "सेटिल्ड अप"
    "dateRemark": "Date/Remark", // "तिथि/टिप्पणी"
    "noEntryAvailable": "No entry available, add now", // "कोई प्रविष्टि उपलब्ध नहीं है, अभी जोड़ें"
    "loading": "Loading...", //

  };

  // --- Hindi Strings ---
  static const Map<String, String> _hindi = {
    "addCustomer": "ग्राहक जोड़ें",
    "searchCustomer": "ग्राहक खोजें",
    "youWillGet": "आपको मिलेगा",
    "youWillGive": "आप देंगे",
    "balance": "शेष",
    "getReport": "रिपोर्ट प्राप्त करें",
    "addNewCompany": "नई कंपनी जोड़ें",
    "addCompany": "कंपनी जोड़ें",
    "companyName": "कंपनी का नाम",
    "updateCompany": "कंपनी अपडेट करें",
    "back": "वापस",
    "downloadReport": "रिपोर्ट डाउनलोड करें",
    "youGive": "आप देंगे",
    "youGet": "आपको मिलेगा",
    "updateCustomer": "ग्राहक अपडेट करें",
    "delete": "हटाएँ",
    "share": "साझा करें",
    "entryDetails": "प्रविष्टि विवरण",
    "editEntry": "प्रविष्टि संपादित करें",
    "safeAndSecure": "सुरक्षित और सुरक्षित",
    "runningBalance": "चलती शेष राशि",
    "save": "सहेजें",
    "youWillGetFrom": "आपको मिलेगा",
    "youWillGiveTo": "आप देंगे",
    "logout": "लॉगआउट",
    "changePassword": "पासवर्ड बदलें",
    "currentPassword": "वर्तमान पासवर्ड",
    "newPassword": "नया पासवर्ड",
    "confirmNewPassword": "नया पासवर्ड पुष्टि करें",
    "update": "अपडेट करें",
    "cancel": "रद्द करें",
    "backupAndDelete": "बैकअप और हटाएँ",
    "currencySetting": "मुद्रा सेटिंग",
    "changeLanguage": "भाषा बदलें",
    "recycleBin": "रिसायकल बिन",
    "staffList": "स्टाफ सूची",
    "allCompanyTrial": "सभी कंपनियों का परीक्षण",
    "addNewStaff": "नया स्टाफ जोड़ें",
    "updateStaff": "स्टाफ अपडेट करें",
    "selectCompaniesAndActions": "कंपनियाँ और कार्रवाइयाँ चुनें",
    "undo": "पूर्ववत करें",
    "name": "नाम",
    "password": "पासवर्ड",
    "userId": "उपयोगकर्ता आईडी",
    "customerName": "ग्राहक का नाम",
    "remark": "टिप्पणी",
    "photoAttachments": "फोटो संलग्नक",
    "close": "बंद करें",
    "edit": "संपादित करें",
    "userType": "उपयोगकर्ता प्रकार",
    "allLanguages": "सभी भाषाएँ",
    "saveSetting": "सेटिंग सहेजें",
    "selectedLanguage": "चयनित भाषा",
    "backupAndDeleteAccount": "बैकअप लें और खाता हटाएं",
    "cloudStorage": "क्लाउड स्टोरेज",
    "easilyBackupData": "अपने सभी डेटा का आसानी से क्लाउड स्टोरेज पर बैकअप लें",
    "quickBackupRestore": "त्वरित बैकअप और पुनर्स्थापना",
    "turnOnBackup": "बैकअप चालू करें"
  };

  // ---- All string keys for code completion and safety ----
  static const addCustomer = 'addCustomer';
  static const searchCustomer = 'searchCustomer';
  static const youWillGet = 'youWillGet';
  static const youWillGive = 'youWillGive';
  static const balance = 'balance';
  static const getReport = 'getReport';
  static const addNewCompany = 'addNewCompany';
  static const addCompany = 'addCompany';
  static const companyName = 'companyName';
  static const updateCompany = 'updateCompany';
  static const back = 'back';
  static const downloadReport = 'downloadReport';
  static const updateCustomer = 'updateCustomer';
  static const delete = 'delete';
  static const share = 'share';
  static const entryDetails = 'entryDetails';
  static const editEntry = 'editEntry';
  static const safeAndSecure = 'safeAndSecure';
  static const runningBalance = 'runningBalance';
  static const save = 'save';
  static const youWillGetFrom = 'youWillGetFrom';
  static const youWillGiveTo = 'youWillGiveTo';
  static const logout = 'logout';
  static const changePassword = 'changePassword';
  static const currentPassword = 'currentPassword';
  static const newPassword = 'newPassword';
  static const confirmNewPassword = 'confirmNewPassword';
  static const update = 'update';
  static const cancel = 'cancel';
  static const backupAndDelete = 'backupAndDelete';
  static const currencySetting = 'currencySetting';
  static const changeLanguage = 'changeLanguage';
  static const recycleBin = 'recycleBin';
  static const staffList = 'staffList';
  static const allCompanyTrial = 'allCompanyTrial';
  static const addNewStaff = 'addNewStaff';
  static const updateStaff = 'updateStaff';
  static const selectCompaniesAndActions = 'selectCompaniesAndActions';
  static const undo = 'undo';
  static const name = 'name';
  static const password = 'password';
  static const userId = 'userId';
  static const customerName = 'customerName';
  static const remark = 'remark';
  static const youGet = 'youGet';
  static const youGive = 'youGive';
  static const photoAttachments = 'photoAttachments';
  static const close = 'close';
  static const edit = 'edit';
  static const userType = 'userType';
  static const allLanguages = 'allLanguages';
  static const saveSetting = 'saveSetting';
  static const selectedLanguage = 'selectedLanguage';
  static const backupAndDeleteAccount = 'backupAndDeleteAccount';
  static const cloudStorage = 'cloudStorage';
  static const easilyBackupData = 'easilyBackupData';
  static const quickBackupRestore = 'quickBackupRestore';
  static const turnOnBackup = 'turnOnBackup';
}