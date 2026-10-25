import 'package:package_info_plus/package_info_plus.dart';
import 'device_login_view.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/utils/app_constants.dart';
import '../controllers/auth_controller.dart';

class LoginView extends GetView<AuthController> {
  const LoginView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // App Icon / Logo
                  Image.asset(
                    'assets/images/logo.png',
                    width: 72,
                    height: 72,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    AppConstants.appName,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'app_tagline'.tr,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Mode Toggle: Login vs Register
                  Obx(
                    () => SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment<bool>(
                          value: false,
                          label: Text('تسجيل الدخول'),
                          icon: Icon(Icons.login),
                        ),
                        ButtonSegment<bool>(
                          value: true,
                          label: Text('حساب جديد'),
                          icon: Icon(Icons.person_add),
                        ),
                      ],
                      selected: {controller.isSignUp.value},
                      onSelectionChanged: (set) =>
                          controller.isSignUp.value = set.first,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Store Name (if Register)
                  Obx(() {
                    if (!controller.isSignUp.value) {
                      return const SizedBox.shrink();
                    }
                    return Column(
                      children: [
                        TextField(
                          controller: controller.storeNameCtrl,
                          decoration: const InputDecoration(
                            labelText: 'اسم المتجر / النشاط',
                            prefixIcon: Icon(Icons.storefront_outlined),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    );
                  }),

                  // Email
                  TextField(
                    controller: controller.emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'البريد الإلكتروني',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Password
                  Obx(
                    () => TextField(
                      controller: controller.passwordCtrl,
                      obscureText: controller.isObscured.value,
                      decoration: InputDecoration(
                        labelText: 'كلمة المرور',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(
                            controller.isObscured.value
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                          onPressed: () => controller.isObscured.toggle(),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Submit Button
                  Obx(
                    () => ElevatedButton(
                      onPressed: controller.auth.isLoading.value
                          ? null
                          : controller.submit,
                      child: controller.auth.isLoading.value
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              controller.isSignUp.value ? 'إنشاء حساب' : 'دخول',
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  OutlinedButton.icon(
                    onPressed: () => showDialog<void>(
                      context: context,
                      builder: (_) => Dialog(
                        clipBehavior: Clip.antiAlias,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            maxWidth: 520,
                            maxHeight: 700,
                          ),
                          child: const DeviceLoginView(dialog: true),
                        ),
                      ),
                    ),
                    icon: const Icon(Icons.qr_code_2),
                    label: const Text('دخول سريع برمز QR'),
                  ),
                  const SizedBox(height: 16),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      'يتطلب الاستخدام حسابًا وموافقة الإدارة بعد تأكيد الدفع. بعد التفعيل يمكنك العمل محليًا دون إنترنت.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                  FutureBuilder<PackageInfo>(
                    future: PackageInfo.fromPlatform(),
                    builder: (context, snapshot) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        snapshot.hasData
                            ? 'ElNota ${snapshot.data!.version} (${snapshot.data!.buildNumber})'
                            : 'ElNota ${AppConstants.appVersion}',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ),
                  // Privacy / Note
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.security_outlined,
                          size: 18,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'بدون كلاود: بيانات مستقلة على كل جهاز. مع اشتراك كلاود نشط: مزامنة بين الأجهزة عند تفعيل خدمة الكلاود.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
