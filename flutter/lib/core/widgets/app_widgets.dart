import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'app_toast.dart';

export 'app_toast.dart';

/// Responsive layout breakpoints.
abstract class Breakpoints {
  static const double mobile = 600;
  static const double tablet = 1024;
}

/// Returns true when screen width is less than [Breakpoints.mobile].
bool isMobile(BuildContext context) =>
    MediaQuery.sizeOf(context).width < Breakpoints.mobile;

/// Returns true when screen width is between mobile and desktop.
bool isTablet(BuildContext context) {
  final w = MediaQuery.sizeOf(context).width;
  return w >= Breakpoints.mobile && w < Breakpoints.tablet;
}

/// Returns true when screen width is >= desktop threshold.
bool isDesktop(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= Breakpoints.tablet;

/// Builds different layouts depending on screen width.
/// Replaces duplicated full-screen variants per size class.
class ResponsiveLayout extends StatelessWidget {
  const ResponsiveLayout({
    super.key,
    required this.mobile,
    this.tablet,
    this.desktop,
  });

  final Widget mobile;
  final Widget? tablet;
  final Widget? desktop;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      if (constraints.maxWidth >= Breakpoints.tablet) {
        return desktop ?? tablet ?? mobile;
      }
      if (constraints.maxWidth >= Breakpoints.mobile) {
        return tablet ?? mobile;
      }
      return mobile;
    });
  }
}

// ─── Loading / empty / error states ─────────────────────────────────────────

/// Full-area centred loading indicator.
class AppLoadingWidget extends StatelessWidget {
  const AppLoadingWidget({super.key, this.message});
  final String? message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator.adaptive(),
          if (message != null) ...[
            const SizedBox(height: 16),
            Text(
              message!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Empty state: one-sentence message and optional action button.
class AppEmptyWidget extends StatelessWidget {
  const AppEmptyWidget({
    super.key,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.icon,
  });

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon ?? Icons.inbox_outlined,
              size: 48,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 20),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

/// Error state with optional retry button.
class AppErrorWidget extends StatelessWidget {
  const AppErrorWidget({
    super.key,
    required this.message,
    this.onRetry,
  });

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: Text('action_retry'.tr),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Offline banner shown at the top of a view when connectivity is absent.
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Theme.of(context).colorScheme.errorContainer,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Icon(
            Icons.cloud_off_rounded,
            size: 16,
            color: Theme.of(context).colorScheme.onErrorContainer,
          ),
          const SizedBox(width: 8),
          Text(
            'status_offline'.tr,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onErrorContainer,
                ),
          ),
        ],
      ),
    );
  }
}

/// Sync-status indicator chip.
enum SyncStatusKind { pending, syncing, synced, failed, savedLocally }

class SyncStatusChip extends StatelessWidget {
  const SyncStatusChip({super.key, required this.status});
  final SyncStatusKind status;

  @override
  Widget build(BuildContext context) {
    final (label, icon, color) = switch (status) {
      SyncStatusKind.pending => (
          'status_sync_pending'.tr,
          Icons.schedule_rounded,
          Colors.orange,
        ),
      SyncStatusKind.syncing => (
          'status_syncing'.tr,
          Icons.sync_rounded,
          Theme.of(context).colorScheme.primary,
        ),
      SyncStatusKind.synced => (
          'status_synced'.tr,
          Icons.cloud_done_rounded,
          Colors.green,
        ),
      SyncStatusKind.failed => (
          'status_sync_failed'.tr,
          Icons.sync_problem_rounded,
          Theme.of(context).colorScheme.error,
        ),
      SyncStatusKind.savedLocally => (
          'status_saved_locally'.tr,
          Icons.save_alt_rounded,
          Colors.blue,
        ),
    };

    return Chip(
      avatar: Icon(icon, size: 14, color: color),
      label: Text(label, style: Theme.of(context).textTheme.labelSmall),
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}

/// Compact section header used in settings and detail screens.
class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 20, 0, 6),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              letterSpacing: 0.8,
              color: Theme.of(context).colorScheme.primary,
            ),
      ),
    );
  }
}

/// Destructive confirmation dialog.
Future<bool> showDestructiveDialog({
  required String title,
  required String content,
  String? confirmLabel,
}) async {
  final result = await Get.dialog<bool>(
    AlertDialog(
      title: Text(title),
      content: Text(content),
      actions: [
        TextButton(
          onPressed: () => Get.back(result: false),
          child: Text('action_cancel'.tr),
        ),
        TextButton(
          onPressed: () => Get.back(result: true),
          style: TextButton.styleFrom(
            foregroundColor: Get.theme.colorScheme.error,
          ),
          child: Text(confirmLabel ?? 'action_delete'.tr),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Shows a concise success toast.
void showSuccessSnack(String message, {String? title}) {
  AppToast.success(message, title: title);
}

/// Shows an error toast with optional retry.
void showErrorSnack(String message, {String? title, VoidCallback? onRetry}) {
  AppToast.error(message, title: title, onRetry: onRetry);
}
