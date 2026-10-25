import 'dart:async';
import '../sync/models/cloud_snapshot.dart';
import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:uuid/uuid.dart';
import '../database/app_database.dart';
import '../network/connectivity_service.dart';
import 'account_access_service.dart';
import 'supabase_service.dart';
import '../utils/app_runtime.dart';

/// Local-midnight policy: missed days coalesce into one current snapshot.
abstract class DailyBackupPolicy {
  static String day(DateTime now) =>
      '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  static bool due(DateTime now, String? lastDay) =>
      lastDay != null && lastDay.compareTo(day(now)) < 0;
}

class DailyBackupService extends GetxService with WidgetsBindingObserver {
  static const backendEnabled =
      !AppRuntime.demo &&
      bool.fromEnvironment('ENABLE_V2_CLOUD_BACKUP', defaultValue: false);
  final busy = false.obs;
  final lastUploaded = Rxn<DateTime>();
  final error = Rxn<String>();
  Timer? _timer;
  StreamSubscription<void>? _reconnect;
  String? get _uid => SupabaseService.to.client?.auth.currentUser?.id;
  String? _displayUser;
  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(const Duration(minutes: 1), (_) => check());
    if (Get.isRegistered<ConnectivityService>()) {
      _reconnect = ConnectivityService.to.onReconnect.listen((_) => check());
    }
    check();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) check();
  }

  Future<bool> check({bool force = false}) async {
    if (busy.value || !Get.isRegistered<AccountAccessService>()) return false;
    final uid = _uid;
    if (_displayUser != uid) {
      _displayUser = uid;
      lastUploaded.value = null;
      error.value = null;
    }
    if (uid == null || !AccountAccessService.to.cloudEnabled) return false;
    final store = GetStorage(), key = 'daily_backup_day:$uid';
    lastUploaded.value = DateTime.tryParse(
      store.read<String>('daily_backup_uploaded:$uid') ?? '',
    );
    final day = DailyBackupPolicy.day(DateTime.now());
    final last = store.read<String>(key);
    if (last == null) {
      await store.write(key, day);
      if (!force) return false;
    }
    if (!force && !DailyBackupPolicy.due(DateTime.now(), last)) return false;
    if (!backendEnabled) {
      error.value =
          'خدمة النسخ السحابي الجديدة لم تُفعّل بعد؛ بيانات الجهاز محفوظة محليًا';
      return false;
    }
    if (!ConnectivityService.to.isOnline.value) return false;
    busy.value = true;
    try {
      await AccountAccessService.to.refreshAccess();
      if (uid != _uid ||
          !AccountAccessService.to.onlineVerified.value ||
          !AccountAccessService.to.cloudEnabled) {
        return false;
      }
      final snapshot = CloudSnapshot.normalize(await DatabaseService.to.dao.exportLocalSnapshot());
      if (utf8.encode(jsonEncode(snapshot)).length > 10 * 1024 * 1024) {
        throw StateError('BACKUP_TOO_LARGE');
      }
      final device =
          store.read<String>('backup_device_id') ?? const Uuid().v4();
      await store.write('backup_device_id', device);
      if (uid != _uid) return false;
      await SupabaseService.to.client!
          .rpc(
            'elnota_v2_upload_backup',
            params: {
              'expected_user': uid,
              'device': device,
              'backup_day': day,
              'payload': snapshot,
            },
          )
          .timeout(const Duration(seconds: 45));
      if (uid != _uid) return false;
      await store.write(key, day);
      lastUploaded.value = DateTime.now();
      await store.write(
        'daily_backup_uploaded:$uid',
        lastUploaded.value!.toIso8601String(),
      );
      error.value = null;
      return true;
    } catch (_) {
      error.value =
          'تعذر رفع النسخة؛ ستُعاد المحاولة عند الاتصال أو فتح التطبيق';
      return false;
    } finally {
      busy.value = false;
    }
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _reconnect?.cancel();
    super.onClose();
  }
}
