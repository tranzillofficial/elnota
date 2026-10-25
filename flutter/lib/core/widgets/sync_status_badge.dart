import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'app_toast.dart';
import '../network/connectivity_service.dart';
import '../sync/services/sync_service.dart';
import '../utils/app_runtime.dart';

/// Interactive AppBar or Header badge showing real-time sync status.
class SyncStatusBadge extends StatelessWidget {
  const SyncStatusBadge({super.key});

  @override
  Widget build(BuildContext context) {
    if (AppRuntime.demo) {
      return const Tooltip(
        message: 'ديمو — البيانات محلية فقط',
        child: Icon(Icons.science_outlined, color: Color(0xFF00845B)),
      );
    }
    if (!Get.isRegistered<SyncService>()) {
      return const SizedBox.shrink();
    }

    final sync = SyncService.to;
    final conn = Get.isRegistered<ConnectivityService>()
        ? ConnectivityService.to
        : null;

    return Obx(() {
      final summary = sync.summary.value;
      final isOnline = conn?.isOnline.value ?? false;

      Widget iconWidget;
      String tooltip;
      Color? iconColor;

      if (summary.isSyncing) {
        iconWidget = const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        );
        tooltip = 'status_syncing'.tr;
      } else if (summary.hasError) {
        iconWidget = const Icon(Icons.sync_problem_rounded, color: Colors.red);
        tooltip = '${'status_sync_failed'.tr}: ${summary.lastError}';
        iconColor = Colors.red;
      } else if (!isOnline) {
        iconWidget = const Icon(Icons.cloud_off_rounded, color: Colors.orange);
        tooltip = summary.hasPending
            ? '${summary.pendingCount} ${'status_sync_pending'.tr} (${'status_offline'.tr})'
            : 'status_offline'.tr;
        iconColor = Colors.orange;
      } else if (summary.hasPending) {
        iconWidget = Badge(
          label: Text('${summary.pendingCount}'),
          child: const Icon(Icons.cloud_upload_outlined),
        );
        tooltip = '${summary.pendingCount} ${'status_sync_pending'.tr}';
      } else {
        iconWidget = const Icon(Icons.cloud_done_rounded, color: Colors.green);
        tooltip = 'status_synced'.tr;
        iconColor = Colors.green;
      }

      return IconButton(
        icon: iconWidget,
        color: iconColor,
        tooltip: tooltip,
        onPressed: () async {
          final ok = await sync.syncNow();
          if (ok) {
            AppToast.success('action_refresh'.tr, title: 'status_synced'.tr);
          }
        },
      );
    });
  }
}
