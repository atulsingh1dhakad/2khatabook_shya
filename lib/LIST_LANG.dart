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
    "easilyBackupData": "Easily backup all your data on Cloud Storage",
    "quickBackupRestore": "Quick Backup & Restore Cloud Storage",
    "turnOnBackup": "Turn on Backup",
    "settledUp": "Settled Up",
    "dateRemark": "Date/Remark",
    "noEntryAvailable": "No entry available, add now",
    "loading": "Loading...",
    "security": "Security",
    "securityNumber": "Security Number",
    "saveSecurityNumber": "Save Security Number",
    "appVersion": "App Version",
    "permissionDenied": "Permission Denied",
    "noPermissionForThisAction": "You don't have permission for this action.",
    "deleteAllPermanently": "Delete All Permanently",
    "entryDeleted": "Entry deleted",
    "permanentDeleteNotImplemented": "Permanent delete not implemented.",
    "failedToLoadRecycleBin": "Failed to load recycle bin.",
    "serverError": "Server error",
    "undoDelete": "Undo Delete",
    "confirmUndoDelete": "Are you sure you want to restore this item?",
    "deletePermanently": "Delete Permanently",
    "confirmDeletePermanently": "Are you sure you want to permanently delete this item?",
    "deleteAll": "Delete All",
    "confirmDeleteAllPermanently": "Are you sure you want to permanently delete all items in the recycle bin? This action cannot be undone.",
    "failedToRestoreLedger": "Failed to restore ledger.",
    "justNow": "just now",
    "minutesAgo": "{n} minutes ago",
    "hoursAgo": "{n} hours ago",
    "daysAgo": "{n} days ago",
    "entryDeletedAgo": "Entry deleted {time}",
    "customerDeletedAgo": "Customer deleted {time}",
    "entryFrom": "Entry from {source}",
    "customerFrom": "Customer from {source}",
    "failedToUpdateBackupStatus": "Failed to update backup status",
    "failedToDeleteBackup": "Failed to delete backup",
    "filters": "Filetrs",
    "filerBy":"FirlerBy",
    "all":"All",
    "sortBy":"Sort By",
    "noneSort":"None",
    "mostRecent":"Most Recent",
    "highestAmount":"Highest Amount",
    "byNameSort":"By Name",
    "oldestSort":"Oldest Sort",
    "leastAMount":"Least Amount",
    "viewResult":"View Result",
    "noRecords":"No Records Found",
    "downloadPdf":"Download PDF",
    "downloadxl":"Download Excel",
    "editStaff": "Edit Staff",
    "saveChanges":"Save Changes",
    "searchCompanyByName" : "Search Company by name  ",
    "staff":"Staff",
    "addStaff":"Add Staff",
    "yourSecurityCode":"Your Security Code ",
    "changeSecurityNumber":"Change Security Number",
    "enterNewSecurityNumber":"Enter New number",
    "on":" ON ",
    "off":" OFF ",
    "languageUpdatedSuccessfully":"Language Updated Successfully",
    "editCustomer": "Edit Customer Details",
    "searchStaff" : "Search Staff",
    "pdfDownlaoded":"PDF downloaded Successfully",
    "customerUpdatedSuccessfully" :" Customer updated successfully "


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
    "backupAndDeleteAccount": "बैकअप लें और अकाउंट हटाएं",
    "cloudStorage": "क्लाउड स्टोरेज",
    "easilyBackupData": "अपने सभी डेटा का क्लाउड स्टोरेज पर आसानी से बैकअप लें",
    "quickBackupRestore": "त्वरित बैकअप और क्लाउड स्टोरेज",
    "turnOnBackup": "बैकअप चालू करें",
    "settledUp": "सेटिल्ड अप",
    "dateRemark": "तिथि/टिप्पणी",
    "noEntryAvailable": "कोई प्रविष्टि उपलब्ध नहीं है, अभी जोड़ें",
    "loading": "लोड हो रहा है...",
    "security": "सुरक्षा",
    "securityNumber": "सुरक्षा संख्या",
    "saveSecurityNumber": "सुरक्षा नंबर सहेजें",
    "appVersion": "ऐप संस्करण",
    "permissionDenied": "अनुमति अस्वीकृत",
    "noPermissionForThisAction": "इस क्रिया के लिए आपके पास अनुमति नहीं है।",
    "deleteAllPermanently": "सभी को स्थायी रूप से हटा दें",
    "entryDeleted": "प्रविष्टि हटा दी गई",
    "permanentDeleteNotImplemented": "स्थायी रूप से हटाना लागू नहीं है।",
    "failedToLoadRecycleBin": "रिसायकल बिन लोड करने में विफल।",
    "serverError": "सर्वर त्रुटि",
    "undoDelete": "पूर्ववत हटाएं",
    "confirmUndoDelete": "क्या आप वाकई इस आइटम को पुनर्स्थापित करना चाहते हैं?",
    "deletePermanently": "स्थायी रूप से हटाएं",
    "confirmDeletePermanently": "क्या आप वाकई इस आइटम को स्थायी रूप से हटाना चाहते हैं?",
    "deleteAll": "सभी हटाएं",
    "confirmDeleteAllPermanently": "क्या आप वाकई रिसायकल बिन में सभी आइटम्स को स्थायी रूप से हटाना चाहते हैं? यह कार्रवाई पूर्ववत नहीं की जा सकती।",
    "failedToRestoreLedger": "लेजर पुनर्स्थापित करने में विफल।",
    "justNow": "अभी",
    "minutesAgo": "{n} मिनट पहले",
    "hoursAgo": "{n} घंटे पहले",
    "daysAgo": "{n} दिन पहले",
    "entryDeletedAgo": "प्रविष्टि {time} हटाई गई",
    "customerDeletedAgo": "ग्राहक {time} हटाया गया",
    "entryFrom": "{source} से प्रविष्टि",
    "customerFrom": "{source} से ग्राहक",
    "failedToUpdateBackupStatus": "बैकअप स्थिति अपडेट करने में विफल",
    "failedToDeleteBackup": "बैकअप हटाना विफल",
    "filters": "फिल्टर",
    "filerBy":"के द्वारा फिल्टर ",
    "all":"सब",
    "sortBy":"क्रमबद्ध करें ",
    "noneSort":"कोई भी सॉर्ट नहीं ",
    "mostRecent":"सबसे हाल का",
    "highestAmount":"उच्चतम राशि",
    "byNameSort":"नाम क्रम से",
    "oldestSort":"सबसे पुराना क्रम से",
    "leastAmount":"सबसे कम राशि",
    "viewResult":"नतीजा देखें ",
    "noRecords":"कोई रिकॉर्ड नहीं मिला",
    "downloadPdf":"पीडीएफ डाउनलोड करें",
    "downloadxl":"एक्सएल डाउनलोड करें",
    "editStaff": "स्टाफ संपादित करें",
    "saveChanges":"बदलाव सहेजें ",
    "searchCompanyByName" : "कंपनी के नाम से खोजें  ",
    "staff":"स्टाफ ",
    "addStaff":"स्टाफ जोंडे",
    "yourSecurityCode":"आपकी सुरक्षा संख्या",
    "changeSecurityNumber":"सुरक्षा संख्या बदलें",
    "enterNewSecurityNumber":"नई संख्या डालें ",
    "on":"चालू है ",
    "off":"बंद है ",
    "languageUpdatedSuccessfully":"भाषा सफलतापूर्वक अपडेट की गई",
    "editCustomer": "कस्टमर की जानकारी संपादित करें",
    "searchStaff" : "स्टाफ दूँडे ",
    "pdfDownlaoded":"pdf सफलता पूर्वक डाउनलोड हो चुकी है  ",
  "customerUpdatedSuccessfully" :" ग्राहक अपडेट हो गया  "


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
  static const security = 'security';
  static const securityNumber = 'securityNumber';
  static const saveSecurityNumber = 'saveSecurityNumber';
  static const appVersion = 'appVersion';
  static const permissionDenied = 'permissionDenied';
  static const noPermissionForThisAction = 'noPermissionForThisAction';
  static const deleteAllPermanently = 'deleteAllPermanently';
  static const entryDeleted = 'entryDeleted';
  static const permanentDeleteNotImplemented = 'permanentDeleteNotImplemented';
  static const failedToLoadRecycleBin = 'failedToLoadRecycleBin';
  static const serverError = 'serverError';
  static const undoDelete = 'undoDelete';
  static const confirmUndoDelete = 'confirmUndoDelete';
  static const deletePermanently = 'deletePermanently';
  static const confirmDeletePermanently = 'confirmDeletePermanently';
  static const deleteAll = 'deleteAll';
  static const confirmDeleteAllPermanently = 'confirmDeleteAllPermanently';
  static const failedToRestoreLedger = 'failedToRestoreLedger';
  static const justNow = 'justNow';
  static const minutesAgo = 'minutesAgo';
  static const hoursAgo = 'hoursAgo';
  static const daysAgo = 'daysAgo';
  static const entryDeletedAgo = 'entryDeletedAgo';
  static const customerDeletedAgo = 'customerDeletedAgo';
  static const entryFrom = 'entryFrom';
  static const customerFrom = 'customerFrom';
}