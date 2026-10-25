import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:get/get.dart';
import 'app/bindings/app_binding.dart';
import 'app/routes/app_pages.dart';
import 'app/theme/app_theme.dart';
import 'core/services/theme_service.dart';
import 'core/services/locale_service.dart';
import 'core/utils/l10n/app_translations.dart';
import 'core/utils/app_constants.dart';
import 'core/utils/app_runtime.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Prefer portrait + landscape (desktop allows all).
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  final arabicFont = FontLoader('Cairo')
    ..addFont(rootBundle.load('assets/fonts/Cairo.ttf'));
  await arabicFont.load();

  // Boot order: storage → services → app.
  await initServices();

  runApp(const ElNotaApp());
}

class ElNotaApp extends StatelessWidget {
  const ElNotaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,

      // ── Localisation ──────────────────────────────────────────────────────
      translations: AppTranslations(),
      locale: LocaleService.to.locale,
      fallbackLocale: const Locale(AppConstants.localeEn),
      supportedLocales: const [
        Locale(AppConstants.localeAr),
        Locale(AppConstants.localeEn),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],

      // ── Theme ─────────────────────────────────────────────────────────────
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeService.to.mode,

      // ── Routing ───────────────────────────────────────────────────────────
      initialRoute: AppPages.initial,
      getPages: AppPages.routes,
      initialBinding: AppBinding(),

      // ── Builder: apply locale-driven text direction globally ───────────────
      builder: (context, child) {
        final isArabic =
            LocaleService.to.locale.languageCode == AppConstants.localeAr;
        return Directionality(
          textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
          child: AppRuntime.demo
              ? Column(
                  children: [
                    Material(
                      color: const Color(0xFFECF7F0),
                      child: SafeArea(
                        bottom: false,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.science_outlined,
                                size: 18,
                                color: Color(0xFF00845B),
                              ),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  'حساب ديمو — بيانات تجريبية محفوظة في هذا المتصفح فقط. لا تتصل بحسابك الحقيقي.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF164C38),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Expanded(child: child ?? const SizedBox.shrink()),
                  ],
                )
              : child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
