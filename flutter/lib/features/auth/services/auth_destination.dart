import '../../../core/utils/app_routes.dart';
import '../../../core/utils/app_runtime.dart';
import '../../admin/repositories/admin_repository.dart';

/// The server role decides the destination; an email address never grants access.
class AuthDestination {
  AuthDestination({Future<bool> Function()? isAdmin})
    : _isAdmin = isAdmin ?? AdminRepository().isAdmin;
  final Future<bool> Function() _isAdmin;

  Future<String> resolve() async {
    if (AppRuntime.demo) return AppRoutes.home;
    try {
      if (await _isAdmin()) return AppRoutes.admin;
    } catch (_) {
      // Unverified roles never bypass customer activation.
    }
    return AppRoutes.home;
  }
}
