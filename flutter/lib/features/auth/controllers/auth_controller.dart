import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/widgets/app_widgets.dart';
import '../services/auth_service.dart';

class AuthController extends GetxController {
  final emailCtrl = TextEditingController();
  final passwordCtrl = TextEditingController();
  final storeNameCtrl = TextEditingController();

  final RxBool isSignUp = false.obs;
  final RxBool isObscured = true.obs;

  AuthService get auth => AuthService.to;

  Future<void> submit() async {
    if (auth.isLoading.value) return;
    final email = emailCtrl.text.trim();
    final password = passwordCtrl.text;

    if (email.isEmpty || !email.contains('@')) {
      showErrorSnack('يرجى إدخال بريد إلكتروني صالح');
      return;
    }
    if (password.length < 6) {
      showErrorSnack('كلمة المرور يجب أن لا تقل عن 6 أحرف');
      return;
    }

    bool success;
    if (isSignUp.value) {
      final storeName = storeNameCtrl.text.trim().isEmpty
          ? 'متجري'
          : storeNameCtrl.text.trim();
      success = await auth.signUp(
        email: email,
        password: password,
        storeName: storeName,
      );
    } else {
      success = await auth.signIn(email: email, password: password);
    }

    if (success) {
      final destination = await auth.landingRoute();
      if (!isClosed) Get.offAllNamed(destination);
    } else if (isSignUp.value &&
        (auth.lastError.value?.startsWith('تم إنشاء الحساب') ?? false)) {
      showSuccessSnack(auth.lastError.value!);
      isSignUp.value = false;
    } else {
      showErrorSnack(
        auth.lastError.value ??
            'تعذر إكمال الطلب. تحقق من البيانات وتأكيد البريد',
      );
    }
  }

  @override
  void onClose() {
    emailCtrl.dispose();
    passwordCtrl.dispose();
    storeNameCtrl.dispose();
    super.onClose();
  }
}
