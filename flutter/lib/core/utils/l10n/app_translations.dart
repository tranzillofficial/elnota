import 'package:get/get.dart';
import 'ar.dart';
import 'en.dart';

/// GetX translation class wiring both locales.
/// Usage: `'key'.tr` anywhere in the widget tree.
class AppTranslations extends Translations {
  @override
  Map<String, Map<String, String>> get keys => {
        'ar_EG': arStrings,
        'ar': arStrings,
        'en_US': enStrings,
        'en': enStrings,
      };
}
