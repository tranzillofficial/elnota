import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/services/account_access_service.dart';
import '../../../core/utils/app_runtime.dart';
import '../../../core/utils/app_routes.dart';
import '../services/auth_destination.dart';
import '../services/auth_service.dart';
import 'activation_view.dart';

class AccountApprovalGate extends StatelessWidget {
  const AccountApprovalGate({super.key, required this.child, this.destination});
  final AuthDestination? destination;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    if (AppRuntime.demo) return child;
    final access = AccountAccessService.to;
    return Obx(() {
      if (!access.resolved.value) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      return access.access.value.active
          ? child
          : _PendingDestination(
              destination: destination,
              key: ValueKey(AuthService.to.currentSession.value?.userId),
            );
    });
  }
}

/// Also handles existing sessions/bookmarks opened directly at /home.
class _PendingDestination extends StatefulWidget {
  const _PendingDestination({super.key, this.destination});
  final AuthDestination? destination;
  @override
  State<_PendingDestination> createState() => _PendingDestinationState();
}

class _PendingDestinationState extends State<_PendingDestination> {
  late final destination = (widget.destination ?? AuthDestination()).resolve();
  bool redirectScheduled = false;
  @override
  Widget build(BuildContext context) => FutureBuilder<String>(
    future: destination,
    builder: (context, snapshot) {
      if (snapshot.data == AppRoutes.admin && !redirectScheduled) {
        redirectScheduled = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) Get.offAllNamed(AppRoutes.admin);
        });
      }
      if (snapshot.connectionState != ConnectionState.done ||
          snapshot.data == AppRoutes.admin) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      return const ActivationView();
    },
  );
}
