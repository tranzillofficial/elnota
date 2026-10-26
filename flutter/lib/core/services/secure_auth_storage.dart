import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Android auth persistence without an unawaited preferences initialization.
/// Session tokens and PKCE verifiers remain separate and scoped to the backend.
class SecureAuthStorage extends LocalStorage implements GotrueAsyncStorage {
  SecureAuthStorage({
    required String backendHost,
    FlutterSecureStorage? storage,
  }) : _prefix = 'elnota.auth.$backendHost',
       _storage = storage ?? const FlutterSecureStorage();

  final String _prefix;
  final FlutterSecureStorage _storage;
  String get _sessionKey => '$_prefix.session';

  @override
  Future<void> initialize() async {
    // Surface platform/keystore failures through the awaited auth initializer.
    await _storage.read(key: _sessionKey);
  }

  @override
  Future<bool> hasAccessToken() async =>
      (await accessToken())?.isNotEmpty == true;

  @override
  Future<String?> accessToken() => _storage.read(key: _sessionKey);

  @override
  Future<void> persistSession(String persistSessionString) =>
      _storage.write(key: _sessionKey, value: persistSessionString);

  @override
  Future<void> removePersistedSession() => _storage.delete(key: _sessionKey);

  @override
  Future<String?> getItem({required String key}) =>
      _storage.read(key: '$_prefix.pkce.$key');

  @override
  Future<void> setItem({required String key, required String value}) =>
      _storage.write(key: '$_prefix.pkce.$key', value: value);

  @override
  Future<void> removeItem({required String key}) =>
      _storage.delete(key: '$_prefix.pkce.$key');
}
