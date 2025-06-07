import 'package:flutter/material.dart';

class languagescreen extends StatefulWidget {
  const languagescreen({super.key});

  @override
  State<languagescreen> createState() => _languagescreenState();
}

class _languagescreenState extends State<languagescreen> {
  final List<String> languages = [
    'English (US)',
    'English (UK)',
    'French',
    'German',
    'Japanese',
  ];

  int selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    // Colors from the screenshot
    const background = Color(0xFFEAF2F4);
    const card = Colors.white;
    const accent = Color(0xFF265E85); // blue for selected
    const darkText = Color(0xFF265E85); // dark text
    const hintText = Color(0xFF6C8A93);

    return Scaffold(
      backgroundColor: background,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: AppBar(
          backgroundColor: const Color(0xFF265E85),
          leading: const BackButton(color: Colors.white),
          elevation: 0,
          title: const Text(
            "Change Language",
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
          children: [
            const SizedBox(height: 20),
            // Selected Language Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18.0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Selected Language",
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
            // All Languages Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "All Languages",
                    style: TextStyle(
                      color: darkText,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      fontFamily: "Poppins",
                    ),
                  ),
                  Text(
                    "See All",
                    style: TextStyle(
                      color: accent,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      fontFamily: "Poppins",
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            // All Languages List
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
                itemCount: languages.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, idx) => GestureDetector(
                  onTap: () => setState(() => selectedIndex = idx),
                  child: _LanguageCard(
                    language: languages[idx],
                    selected: idx == selectedIndex,
                    accent: accent,
                    darkText: darkText,
                  ),
                ),
              ),
            ),
            // Save Settings Button
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
                  onPressed: () {
                    // Save logic here
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Save Settings",
                        style: TextStyle(
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

// Language Card Widget
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
          // Language Icon circle
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: selected ? Colors.white.withOpacity(0.8) : Color(0xFFF3F6F8),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Icon(
                Icons.language,
                color: selected ? accent : Color(0xFFB1C6CB),
                size: 23,
              ),
            ),
          ),
          const SizedBox(width: 15),
          // Language Name
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
          // Radio circle
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              border: Border.all(
                color: selected ? Colors.white : Color(0xFFB1C6CB),
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
                decoration: BoxDecoration(
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