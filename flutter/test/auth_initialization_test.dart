import 'dart:async';

import 'package:elnota/core/services/supabase_service.dart';
import 'package:elnota/core/services/secure_auth_storage.dart';
import 'package:elnota/features/auth/services/auth_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get/get.dart';

class _InitializationProbe extends SupabaseService {
  int attempts = 0;
  Future<void> Function()? initialize;

  @override
  Future<void> init({String? url, String? anonKey}) async {
    attempts++;
    await initialize?.call();
  }
}

class _UnavailableStorage implements FlutterSecureStorage {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('keystore temporarily unavailable');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => Get.testMode = true);
  tearDown(() => Get.reset());

  test(
    'Android sessions survive a new storage instance and isolate PKCE and backends',
    () async {
      FlutterSecureStorage.setMockInitialValues({});
      final storage = SecureAuthStorage(backendHost: 'first.example');
      await storage.initialize();
      expect(await storage.hasAccessToken(), false);
      await storage.persistSession('test-session');
      await storage.setItem(key: 'verifier', value: 'test-verifier');
      final restored = SecureAuthStorage(backendHost: 'first.example');
      await restored.initialize();
      expect(await restored.accessToken(), 'test-session');
      expect(await restored.getItem(key: 'verifier'), 'test-verifier');
      expect(
        await SecureAuthStorage(backendHost: 'other.example').hasAccessToken(),
        false,
      );
      await restored.removePersistedSession();
      expect(await restored.hasAccessToken(), false);
      expect(await restored.getItem(key: 'verifier'), 'test-verifier');
      await restored.removeItem(key: 'verifier');
      expect(await restored.getItem(key: 'verifier'), isNull);
    },
  );

  test('keystore initialization failures stay on the awaited future', () async {
    final storage = SecureAuthStorage(
      backendHost: 'first.example',
      storage: _UnavailableStorage(),
    );
    await expectLater(storage.initialize(), throwsStateError);
  });

  test(
    'concurrent callers share initialization and can retry a failure',
    () async {
      final pending = Completer<void>();
      final service = _InitializationProbe()..initialize = () => pending.future;
      final first = service.ensureInitialized();
      final second = service.ensureInitialized();
      expect(service.attempts, 1);
      final assertions = [
        expectLater(first, throwsStateError),
        expectLater(second, throwsStateError),
      ];
      pending.completeError(StateError('storage temporarily unavailable'));
      await Future.wait(assertions);
      service.initialize = () async {};
      await service.ensureInitialized();
      expect(service.attempts, 2);
    },
  );

  test(
    'both login and signup retry unavailable initialization and stay locked',
    () async {
      final service = _InitializationProbe();
      Get.put<SupabaseService>(service);
      final auth = Get.put(AuthService());
      expect(
        await auth.signIn(
          email: 'test@example.invalid',
          password: 'test-password',
        ),
        false,
      );
      expect(service.attempts, 1);
      expect(
        await auth.signUp(
          email: 'test@example.invalid',
          password: 'test-password',
          storeName: 'Test',
        ),
        false,
      );
      expect(service.attempts, 2);
      expect(auth.currentSession.value, isNull);
      expect(auth.isLoading.value, false);
    },
  );
}
