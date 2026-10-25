import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService extends GetxService {
  static SupabaseService get to => Get.find<SupabaseService>();

  final _secureStorage = const FlutterSecureStorage();
  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;
  SupabaseClient? get client =>
      _isInitialized ? Supabase.instance.client : null;

  static const String _keySession = 'supabase_session';

  Future<void> init({String? url, String? anonKey}) async {
    // Only initialize if non-empty valid URL is passed
    if (url != null &&
        url.isNotEmpty &&
        anonKey != null &&
        anonKey.isNotEmpty) {
      try {
        await Supabase.initialize(
          url: url,
          publishableKey: anonKey,
          authOptions: const FlutterAuthClientOptions(
            authFlowType: AuthFlowType.pkce,
          ),
        );
        _isInitialized = true;
      } catch (_) {
        _isInitialized = false;
      }
    }
  }

  Future<void> saveSecureToken(String token) async {
    await _secureStorage.write(key: _keySession, value: token);
  }

  Future<String?> getSecureToken() async {
    return _secureStorage.read(key: _keySession);
  }

  Future<void> clearSecureSession() async {
    await _secureStorage.delete(key: _keySession);
  }
}
