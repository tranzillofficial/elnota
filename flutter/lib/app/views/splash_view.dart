import '../../features/auth/services/auth_service.dart';
import '../../core/services/supabase_service.dart';
import '../../features/auth/services/device_login_service.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/utils/app_routes.dart';
import '../../core/utils/app_runtime.dart';
import '../../core/utils/app_constants.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// Splash / launch screen.
/// In Phase 1 it simply shows the brand and navigates to [AppRoutes.home]
/// after a short delay. Phase 3 will add auth-state checking here.
class SplashView extends StatefulWidget {
  const SplashView({super.key});

  @override
  State<SplashView> createState() => _SplashViewState();
}

class _SplashViewState extends State<SplashView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fadeAnim;
  late final Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fadeAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
    _scaleAnim = Tween<double>(
      begin: 0.85,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack));

    _ctrl.forward();
    _navigateAfterDelay();
  }

  void _navigateAfterDelay() {
    Future.delayed(const Duration(milliseconds: 1800), () async {
      if (mounted) {
        final loggedIn =
            Get.isRegistered<SupabaseService>() &&
            SupabaseService.to.client?.auth.currentSession != null;
        final destination = AppRuntime.demo
            ? AppRoutes.home
            : !loggedIn
            ? AppRoutes.login
            : await AuthService.to.landingRoute();
        if (!mounted) return;
        Get.offAllNamed(destination);
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => DeviceLinkBridge.initialize(),
        );
      }
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.canvasDark : AppColors.canvasLight;

    return Scaffold(
      backgroundColor: bg,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: ScaleTransition(
          scale: _scaleAnim,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Logo mark ──────────────────────────────────────────────
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.receipt_long_rounded,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
                const SizedBox(height: 20),
                // ── App name ────────────────────────────────────────────────
                Text(
                  AppConstants.appName,
                  style: AppTextStyles.display.copyWith(
                    color: AppColors.accent,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'app_tagline'.tr,
                  style: AppTextStyles.body.copyWith(
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                ),
                const SizedBox(height: 48),
                SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: AppColors.accent.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
