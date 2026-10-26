import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/backend_config.dart';
import 'secure_auth_storage.dart';

class SupabaseService extends GetxService {
  static SupabaseService get to => Get.find<SupabaseService>();

  final _secureStorage = const FlutterSecureStorage();
  bool _isInitialized = false;
  Future<void>? _initializing;
  String? initializationFailure;

  Future<void> ensureInitialized() async {
    if (_isInitialized) return;
    final pending = _initializing ??= init(
      url: BackendConfig.url,
      anonKey: BackendConfig.publishableKey,
    );
    try {
      await pending;
    } finally {
      _initializing = null;
    }
  }

  bool get isInitialized => _isInitialized;
  SupabaseClient? get client =>
      _isInitialized ? Supabase.instance.client : null;

  static const String _keySession = 'supabase_session';

  Future<void> init({String? url, String? anonKey}) async {
    if (_isInitialized) return;
    initializationFailure = null;
    // Only initialize if non-empty valid URL is passed
    if (url != null &&
        url.isNotEmpty &&
        anonKey != null &&
        anonKey.isNotEmpty) {
      try {
        final androidStorage =
            !kIsWeb && defaultTargetPlatform == TargetPlatform.android
            ? SecureAuthStorage(backendHost: Uri.parse(url).host)
            : null;
        await Supabase.initialize(
          url: url,
          publishableKey: anonKey,
          authOptions: FlutterAuthClientOptions(
            authFlowType: AuthFlowType.pkce,
            localStorage: androidStorage,
            pkceAsyncStorage: androidStorage,
          ),
        );
        _isInitialized = true;
      } catch (error) {
        // Retain only the error type: exception text may contain session data.
        initializationFailure = error.runtimeType.toString();
        _isInitialized = false;
        // initialize() can create the singleton before storage/deep links fail.
        // Dispose that partial instance so the next attempt really initializes
        // auth instead of returning an incompletely configured singleton.
        try {
          await Supabase.instance.dispose();
        } catch (_) {
          // Nothing to dispose if creation itself failed.
        }
      }
    } else {
      initializationFailure = 'MissingBackendConfiguration';
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
