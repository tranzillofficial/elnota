import 'package:get/get.dart';
import '../repositories/admin_repository.dart';

class AdminController extends GetxController {
  AdminController(this.gateway);
  final AdminGateway gateway;
  final loading = false.obs;
  final allowed = false.obs;
  final busy = false.obs;
  final error = Rxn<String>();
  final accountRows = <Map<String, dynamic>>[].obs;
  final requestRows = <Map<String, dynamic>>[].obs;
  final page = 0.obs;
  @override
  void onInit() {
    super.onInit();
    refreshData();
  }

  Future<void> refreshData() async {
    if (loading.value) return;
    loading.value = true;
    error.value = null;
    try {
      allowed.value = await gateway.isAdmin();
      if (!allowed.value) {
        accountRows.clear();
        requestRows.clear();
        return;
      }
      final result = await Future.wait([
        gateway.accounts(page.value),
        gateway.requests(page.value),
      ]);
      if (isClosed) return;
      accountRows.assignAll(result[0]);
      requestRows.assignAll(result[1]);
    } catch (_) {
      allowed.value = false;
      accountRows.clear();
      requestRows.clear();
      error.value = 'تعذر التحقق من صلاحيات الإدارة أو تحميل البيانات';
    } finally {
      if (!isClosed) loading.value = false;
    }
  }

  Future<bool> reviewRequest(String id, bool approve) =>
      _write(() => gateway.review(id, approve));
  Future<bool> changePrinting(String id, bool enabled) =>
      _write(() => gateway.setPrinting(id, enabled));
  Future<bool> changeCatalog(String id, bool enabled) =>
      _write(() => gateway.setCatalog(id, enabled));
  Future<bool> manageAccount(String id, String operation) => _write(() async {
    final controls = gateway;
    if (controls is! AdminAccountControls) {
      throw StateError('الإدارة غير متاحة');
    }
    await (controls as AdminAccountControls).manageAccount(id, operation);
  });
  Future<bool> manageCloud(String id, String plan) => _write(() async {
    final controls = gateway;
    if (controls is! AdminAccountControls) {
      throw StateError('الإدارة غير متاحة');
    }
    await (controls as AdminAccountControls).manageCloud(id, plan);
  });

  Future<bool> _write(Future<void> Function() action) async {
    if (busy.value || !allowed.value || !AdminRepository.writesEnabled) {
      return false;
    }
    busy.value = true;
    try {
      await action();
      await refreshData();
      return true;
    } catch (_) {
      error.value = 'لم يتم تأكيد التغيير. حدّث الصفحة قبل إعادة المحاولة.';
      return false;
    } finally {
      if (!isClosed) busy.value = false;
    }
  }
}
