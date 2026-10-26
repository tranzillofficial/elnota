import 'dart:async';

import 'package:get/get.dart';

import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'supabase_service.dart';
import '../utils/app_runtime.dart';

class AccountAccess {
  const AccountAccess({
    this.active = false,
    this.cloudUntil,
    this.catalogOverride,
    this.printingEnabled = false,
  });
  final bool active;
  final bool? catalogOverride;
  final bool printingEnabled;
  final DateTime? cloudUntil;
  bool cloudAt(DateTime now) =>
      active && cloudUntil != null && cloudUntil!.isAfter(now);
  bool catalogAt(DateTime now) => active && (catalogOverride ?? cloudAt(now));
  factory AccountAccess.fromMap(Map<String, dynamic> row) => AccountAccess(
    active:
        row['activated_at'] != null &&
        row['suspended_at'] == null &&
        row['deleted_at'] == null,
    cloudUntil: DateTime.tryParse(row['cloud_until'] as String? ?? ''),
    catalogOverride: row['catalog_enabled'] as bool?,
    printingEnabled: row['printing_enabled'] == true,
  );
}

class AccountAccessService extends GetxService {
  AccountAccessService({this.automaticallyRefresh = true});
  final bool automaticallyRefresh;
  static AccountAccessService get to => Get.find();
  final access = const AccountAccess().obs;
  final loading = false.obs;
  final onlineVerified = false.obs;
  final resolved = false.obs;
  final _secureCache = const FlutterSecureStorage();
  String? _cacheUser;
  Completer<void>? _refreshDone;

  void resetForAccount(String? uid) {
    if (_cacheUser == uid) return;
    access.value = const AccountAccess();
    resolved.value = false;
    onlineVerified.value = false;
  }

  Timer? _timer;
  StreamSubscription<dynamic>? _auth;
  bool get cloudEnabled => access.value.cloudAt(DateTime.now());
  bool get catalogEnabled => access.value.catalogAt(DateTime.now());
  bool get printingEnabled =>
      access.value.active && access.value.printingEnabled;
  String? get _uid => SupabaseService.to.client?.auth.currentUser?.id;
  @override
  void onInit() {
    super.onInit();
    if (!automaticallyRefresh) return;
    _auth = SupabaseService.to.client?.auth.onAuthStateChange.listen((_) {
      resetForAccount(_uid);
      refreshAccess();
    });
    refreshAccess();
    _timer = Timer.periodic(const Duration(minutes: 5), (_) => refreshAccess());
  }

  Future<void> refreshAccess() async {
    if (AppRuntime.demo) return;
    if (loading.value) {
      await _refreshDone?.future;
      if (_cacheUser != _uid) await refreshAccess();
      return;
    }
    final uid = _uid;
    onlineVerified.value = false;
    if (uid == null) {
      _cacheUser = null;
      access.value = const AccountAccess();
      resolved.value = true;
      return;
    }
    loading.value = true;
    final done = Completer<void>();
    _refreshDone = done;
    if (_cacheUser != uid) {
      access.value = const AccountAccess();
      resolved.value = false;
      try {
        final cached = await _secureCache.read(key: 'verified_access:$uid');
        if (_uid != uid) {
          loading.value = false;
          done.complete();
          return;
        }
        if (cached != null) {
          access.value = AccountAccess.fromMap(
            Map<String, dynamic>.from(jsonDecode(cached) as Map),
          );
        }
      } catch (_) {
        // A first verified online login is required if secure cache is unavailable.
      } finally {
        _cacheUser = uid;
        resolved.value = true;
      }
    }
    try {
      final client = SupabaseService.to.client!;
      final row = await client
          .from('elnota_accounts')
          .select(
            'activated_at,cloud_until,suspended_at,deleted_at,printing_enabled',
          )
          .eq('user_id', uid)
          .maybeSingle();
      bool? override;
      try {
        final feature = await client
            .from('elnota_feature_access')
            .select('catalog_enabled')
            .eq('user_id', uid)
            .maybeSingle();
        override = feature?['catalog_enabled'] as bool?;
      } catch (_) {
        /* Older backend has no override contract. Deny the override. */
      }
      if (_uid != uid) return;
      final values = <String, dynamic>{...?row, 'catalog_enabled': override};
      access.value = AccountAccess.fromMap(values);
      onlineVerified.value = true;
      try {
        await _secureCache.write(
          key: 'verified_access:$uid',
          value: jsonEncode(values),
        );
      } catch (_) {
        // Online access works; a failed cache write cannot grant offline access.
      }
    } catch (_) {
      /* Keep this account's last verified entitlement for offline work. */
    } finally {
      loading.value = false;
      resolved.value = true;
      if (!done.isCompleted) done.complete();
    }
  }

  @override
  void onClose() {
    _timer?.cancel();
    _auth?.cancel();
    super.onClose();
  }
}
