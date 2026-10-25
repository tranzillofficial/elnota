import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'supabase_service.dart';

/// Printer/business preferences belong to the signed-in account on this device.
abstract class BusinessProfile {
  static String get key {
    final user = Get.isRegistered<SupabaseService>()
        ? SupabaseService.to.client?.auth.currentUser?.id
        : null;
    return user == null ? 'business_profile' : 'business_profile:$user';
  }

  static Map<dynamic, dynamic> get values => GetStorage().read<Map>(key) ?? {};
}
