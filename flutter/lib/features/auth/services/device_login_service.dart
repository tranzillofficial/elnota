import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import '../../../core/services/supabase_service.dart';
import '../views/device_login_view.dart';

class DeviceLoginApi {
  static Future<Map<String, dynamic>> invoke(Map<String, dynamic> body) async {
    final client = Get.isRegistered<SupabaseService>()
        ? SupabaseService.to.client
        : null;
    if (client == null) {
      throw StateError('يجب إعداد اتصال الحساب قبل ربط الأجهزة');
    }
    final response = await client.functions.invoke('device-login', body: body);
    if (response.status != 200 || response.data is! Map) {
      throw StateError('تعذر ربط الجهاز');
    }
    return Map<String, dynamic>.from(response.data as Map);
  }
}

class DeviceLinkBridge {
  static const channel = MethodChannel('elnota/device_links');
  static bool _started = false;
  static Future<void> initialize() async {
    if (_started || kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return;
    }
    _started = true;
    channel.setMethodCallHandler((call) async {
      if (call.method == 'link' && call.arguments is String) {
        _open(call.arguments as String);
      }
    });
    try {
      final link = await channel.invokeMethod<String>('initialLink');
      if (link != null) _open(link);
    } on MissingPluginException {
      /* Non-Android tests do not register the native bridge. */
    }
  }

  static void _open(String text) {
    final uri = Uri.tryParse(text);
    final id = uri?.queryParameters['challenge'];
    if (uri?.scheme != 'elnota' ||
        uri?.host != 'link-device' ||
        id == null ||
        !RegExp(r'^[0-9a-f-]{36}$', caseSensitive: false).hasMatch(id)) {
      return;
    }
    Get.to(() => DeviceApprovalView(challengeId: id));
  }
}
