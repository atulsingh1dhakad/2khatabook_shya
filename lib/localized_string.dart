import 'LIST_LANG.dart'; // <-- Add this line

String localizedString(String key) {
  return AppStrings.instance.get(key);
}