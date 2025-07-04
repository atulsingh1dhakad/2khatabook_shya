import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../LIST_LANG.dart';

class LanguagesScreen extends StatefulWidget {
  final Function(String) onLanguageChanged;

  const LanguagesScreen({super.key, required this.onLanguageChanged});

  @override
  State<LanguagesScreen> createState() => _LanguagesScreenState();
}

class _LanguagesScreenState extends State<LanguagesScreen> {
  final List<String> languageCodes = ['en', 'hi'];
  int selectedIndex = 0;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSelectedLanguage();
  }

  String get selectedLangCode => languageCodes[selectedIndex];

  Future<void> _loadSelectedLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    final savedLang = prefs.getString('app_language') ?? 'en';
    setState(() {
      selectedIndex = languageCodes.indexOf(savedLang);
      if (selectedIndex == -1) selectedIndex = 0;
      AppStrings.setLanguage(languageCodes[selectedIndex]);
    });
  }

  Future<void> _persistSelectedLanguage(String langCode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_language', langCode);
  }

  /// Save selected language, notify parent via callback, pop to previous screen.
  Future<void> _saveLanguage() async {
    setState(() => isLoading = true);
    await _persistSelectedLanguage(selectedLangCode);
    AppStrings.setLanguage(selectedLangCode); // update language globally
    widget.onLanguageChanged(selectedLangCode);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppStrings.getString("languageUpdatedSuccessfully") ?? "Language updated successfully!")),
    );

    Navigator.of(context).pop(); // Pop LanguagesScreen
  }

  @override
  Widget build(BuildContext context) {
    // Colors
    const background = Color(0xFFEAF2F4);
    const accent = Color(0xFF265E85);
    const darkText = Color(0xFF265E85);
    const hintText = Color(0xFF6C8A93);

    // Language names using localization
    final List<String> languages = [
      AppStrings.getString("english") ?? "English",
      AppStrings.getString("हिन्दी") ?? "Hindi",
    ];

    return Scaffold(
      backgroundColor: background,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: AppBar(
          backgroundColor: accent,
          leading: const BackButton(color: Colors.white),
          elevation: 0,
          title: Text(
            AppStrings.getString("changeLanguage"),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
          ),
          centerTitle: true,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(22)),
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18.0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  AppStrings.getString("selectedLanguage"),
                  style: TextStyle(
                    color: hintText,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    fontFamily: "Poppins",
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: _LanguageCard(
                language: languages[selectedIndex],
                selected: true,
                accent: accent,
                darkText: darkText,
              ),
            ),
            const SizedBox(height: 26),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    AppStrings.getString("allLanguages"),
                    style: TextStyle(
                      color: darkText,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      fontFamily: "Poppins",
                    ),
                  ),
                  const SizedBox(),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
                itemCount: languages.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, idx) => GestureDetector(
                  onTap: () => setState(() {
                    selectedIndex = idx;
                    AppStrings.setLanguage(languageCodes[selectedIndex]);
                  }),
                  child: _LanguageCard(
                    language: languages[idx],
                    selected: idx == selectedIndex,
                    accent: accent,
                    darkText: darkText,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 18, right: 18, bottom: 24),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: darkText,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                    elevation: 0,
                  ),
                  onPressed: isLoading ? null : _saveLanguage,
                  child: isLoading
                      ? const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  )
                      : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        AppStrings.getString("saveSetting"),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                          fontFamily: "Poppins",
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Icon(Icons.check, color: Colors.white, size: 26),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LanguageCard extends StatelessWidget {
  final String language;
  final bool selected;
  final Color accent;
  final Color darkText;
  const _LanguageCard({
    required this.language,
    required this.selected,
    required this.accent,
    required this.darkText,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: selected ? accent : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: selected ? accent : Colors.transparent,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 2,
            offset: Offset(0, 1),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 14),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: selected ? Colors.white.withOpacity(0.8) : const Color(0xFFF3F6F8),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Icon(
                Icons.language,
                color: selected ? accent : const Color(0xFFB1C6CB),
                size: 23,
              ),
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Text(
              language,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : darkText,
                fontFamily: "Poppins",
              ),
            ),
          ),
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              border: Border.all(
                color: selected ? Colors.white : const Color(0xFFB1C6CB),
                width: 2.5,
              ),
              shape: BoxShape.circle,
              color: selected ? accent : Colors.white,
            ),
            child: selected
                ? Center(
              child: Container(
                width: 12,
                height: 12,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
            )
                : null,
          ),
        ],
      ),
    );
  }
}