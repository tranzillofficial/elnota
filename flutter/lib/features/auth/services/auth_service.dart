import 'auth_destination.dart';
import '../../../core/services/account_access_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/database/app_database.dart';
import '../../../core/sync/services/sync_service.dart';
import 'package:get/get.dart';
import '../../../core/services/supabase_service.dart';
import '../models/user_session.dart';
import '../../../core/utils/app_runtime.dart';

class AuthService extends GetxService {
  static AuthService get to => Get.find<AuthService>();

  final Rx<UserSession?> currentSession = Rx<UserSession?>(null);
  final RxBool isLoading = false.obs;
  final lastError = Rxn<String>();

  Future<String> landingRoute() => AuthDestination().resolve();

  bool get isAuthenticated => currentSession.value != null;
  String get activeWorkspaceId =>
      currentSession.value?.workspaceId ?? 'default';

  @override
  void onInit() {
    super.onInit();
    _restoreLocalSession();
  }

  void _restoreLocalSession() {
    if (AppRuntime.demo) {
      currentSession.value = const UserSession(
        userId: 'demo',
        email: 'demo@elnota.local',
        workspaceId: 'default',
        workspaceName: 'النوتة — حساب ديمو',
      );
      return;
    }
    final user = Get.isRegistered<SupabaseService>()
        ? SupabaseService.to.client?.auth.currentUser
        : null;
    if (user != null) {
      currentSession.value = UserSession(
        userId: user.id,
        email: user.email ?? '',
        workspaceId: user.appMetadata['workspace_id'] as String? ?? user.id,
        workspaceName:
            user.userMetadata?['workspace_name'] as String? ?? 'النوتة',
      );
      return;
    }
    // No anonymous/local owner is created. Offline access requires a prior login.
    currentSession.value = null;
  }

  Future<void> acceptServerSession() async {
    if (AppRuntime.demo) {
      throw StateError('الديمو لا يدعم الدخول إلى حساب حقيقي');
    }
    final user = SupabaseService.to.client?.auth.currentUser;
    if (user == null) throw StateError('Authenticated session required');
    if (Get.isRegistered<DatabaseService>()) {
      if (Get.isRegistered<SyncService>()) {
        await Get.delete<SyncService>(force: true);
      }
      await DatabaseService.to.switchAccount(user.id);
      Get.put<SyncService>(SyncService(), permanent: true);
    }
    _restoreLocalSession();
    if (Get.isRegistered<AccountAccessService>()) {
      AccountAccessService.to.resetForAccount(user.id);
    }
    // Idempotent registration does not activate the account or touch its ledger.
    try {
      await SupabaseService.to.client!.rpc(
        'elnota_register',
        params: {'business': currentSession.value?.workspaceName ?? 'النوتة'},
      );
    } catch (_) {
      // Entitlement remains denied if registration could not be verified.
    }
    if (Get.isRegistered<AccountAccessService>()) {
      await AccountAccessService.to.refreshAccess();
    }
  }

  Future<bool> signIn({required String email, required String password}) async {
    if (AppRuntime.demo) return false;
    lastError.value = null;
    isLoading.value = true;
    try {
      final supa = SupabaseService.to;
      await supa.ensureInitialized();
      if (supa.isInitialized && supa.client != null) {
        final res = await supa.client!.auth.signInWithPassword(
          email: email.trim().toLowerCase(),
          password: password,
        );
        final user = res.user;
        if (user != null) {
          await acceptServerSession();
          return true;
        }
      }
      lastError.value =
          'تعذر تهيئة خدمة الحساب. تأكد من اتصال الإنترنت واستعمال آخر إصدار.';
      return false;
    } on AuthException catch (e) {
      lastError.value = e.code == 'invalid_credentials'
          ? 'البريد أو كلمة المرور غير صحيحة'
          : e.code == 'email_not_confirmed'
          ? 'أكد البريد الإلكتروني قبل تسجيل الدخول'
          : 'تعذر تسجيل الدخول. راجع البيانات وحاول مرة أخرى';
      return false;
    } catch (_) {
      lastError.value =
          'تعذر الاتصال بخدمة الحساب. تحقق من الإنترنت وحاول مرة أخرى';
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> signUp({
    required String email,
    required String password,
    required String storeName,
  }) async {
    if (AppRuntime.demo) return false;
    lastError.value = null;
    isLoading.value = true;
    try {
      final supa = SupabaseService.to;
      await supa.ensureInitialized();
      if (supa.isInitialized && supa.client != null) {
        final res = await supa.client!.auth.signUp(
          email: email.trim().toLowerCase(),
          password: password,
          data: {'workspace_name': storeName},
        );
        final user = res.user;
        if (user != null) {
          if (res.session == null) {
            lastError.value =
                'تم إنشاء الحساب. أكّد بريدك الإلكتروني ثم سجّل الدخول لإرسال طلب التفعيل.';
            return false;
          }
          await acceptServerSession();
          return true;
        }
      }
      lastError.value =
          'تعذر تهيئة خدمة الحساب. تأكد من اتصال الإنترنت واستعمال آخر إصدار.';
      return false;
    } on AuthException catch (e) {
      lastError.value = e.code == 'user_already_exists'
          ? 'هذا البريد مسجل بالفعل. استخدم تسجيل الدخول.'
          : e.code == 'over_email_send_rate_limit'
          ? 'تم إرسال طلبات كثيرة. انتظر قليلًا قبل المحاولة.'
          : 'تعذر إنشاء الحساب. راجع البريد وكلمة المرور واتصال الإنترنت.';
      return false;
    } catch (_) {
      lastError.value =
          'تعذر الاتصال بخدمة الحساب. تحقق من الإنترنت وحاول مرة أخرى';
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> signOut() async {
    if (AppRuntime.demo) return;
    lastError.value = null;
    isLoading.value = true;
    try {
      final supa = SupabaseService.to;
      if (supa.isInitialized && supa.client != null) {
        await supa.client!.auth.signOut(scope: SignOutScope.local);
      }
      await supa.clearSecureSession();
      if (Get.isRegistered<DatabaseService>()) {
        if (Get.isRegistered<SyncService>()) {
          await Get.delete<SyncService>(force: true);
        }
        await DatabaseService.to.switchAccount(null);
        Get.put<SyncService>(SyncService(), permanent: true);
      }
      currentSession.value = null;
      if (Get.isRegistered<AccountAccessService>()) {
        AccountAccessService.to.resetForAccount(null);
        await AccountAccessService.to.refreshAccess();
      }
    } finally {
      isLoading.value = false;
    }
  }
}
