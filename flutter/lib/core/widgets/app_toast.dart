import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

/// Modern smart toast notification system with premium styling and haptics.
abstract class AppToast {
  static void success(String message, {String? title}) {
    HapticFeedback.lightImpact();
    _show(
      title: title ?? 'تم بنجاح',
      message: message,
      icon: Icons.check_circle_rounded,
      backgroundColor: const Color(0xFF1B5E20),
      iconColor: const Color(0xFF81C784),
    );
  }

  static void info(String message, {String? title}) {
    HapticFeedback.selectionClick();
    _show(
      title: title ?? 'تنبيه',
      message: message,
      icon: Icons.info_rounded,
      backgroundColor: const Color(0xFF0D47A1),
      iconColor: const Color(0xFF64B5F6),
    );
  }

  static void warning(String message, {String? title}) {
    HapticFeedback.mediumImpact();
    _show(
      title: title ?? 'تحذير',
      message: message,
      icon: Icons.warning_amber_rounded,
      backgroundColor: const Color(0xFFE65100),
      iconColor: const Color(0xFFFFB74D),
    );
  }

  static void error(String message, {String? title, VoidCallback? onRetry}) {
    HapticFeedback.heavyImpact();
    _show(
      title: title ?? 'حدث خطأ',
      message: message,
      icon: Icons.error_rounded,
      backgroundColor: const Color(0xFFB71C1C),
      iconColor: const Color(0xFFE57373),
      duration: const Duration(seconds: 4),
      onRetry: onRetry,
    );
  }

  static void _show({
    required String title,
    required String message,
    required IconData icon,
    required Color backgroundColor,
    required Color iconColor,
    Duration duration = const Duration(seconds: 3),
    VoidCallback? onRetry,
  }) {
    Get.rawSnackbar(
      titleText: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
      messageText: Text(
        message,
        style: const TextStyle(color: Colors.white70, fontSize: 13),
      ),
      icon: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor, size: 22),
      ),
      snackPosition: SnackPosition.TOP,
      maxWidth: 440,
      backgroundColor: backgroundColor,
      borderRadius: 14,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      duration: duration,
      boxShadows: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.25),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
      ],
      mainButton: onRetry != null
          ? TextButton(
              onPressed: () {
                Get.closeCurrentSnackbar();
                onRetry();
              },
              child: Text(
                'action_retry'.tr,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          : null,
    );
  }
}
