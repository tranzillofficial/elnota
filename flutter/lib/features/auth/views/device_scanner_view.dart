import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'device_login_view.dart';

class DeviceScannerView extends StatefulWidget {
  const DeviceScannerView({super.key});
  @override
  State<DeviceScannerView> createState() => _DeviceScannerViewState();
}

class _DeviceScannerViewState extends State<DeviceScannerView> {
  final camera = MobileScannerController(formats: [BarcodeFormat.qrCode]);
  bool found = false;
  String? error;
  void detect(BarcodeCapture result) {
    if (found) return;
    for (final barcode in result.barcodes) {
      final uri = Uri.tryParse(barcode.rawValue ?? '');
      final id = uri?.queryParameters['challenge'];
      if (uri?.scheme != 'elnota' ||
          uri?.host != 'link-device' ||
          id == null ||
          !RegExp(
            r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
            caseSensitive: false,
          ).hasMatch(id)) {
        setState(() => error = 'الرمز ليس طلب ربط من النوتة');
        continue;
      }
      found = true;
      camera.stop();
      Get.off(() => DeviceApprovalView(challengeId: id));
      return;
    }
  }

  @override
  void dispose() {
    camera.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('مسح رمز ربط الويب')),
    body: Column(
      children: [
        const Padding(
          padding: EdgeInsets.all(20),
          child: Text(
            'وجّه الكاميرا لرمز QR في صفحة دخول النوتة على الكمبيوتر. هتقارن كود التأكيد قبل الموافقة.',
            textAlign: TextAlign.center,
          ),
        ),
        Expanded(
          child: MobileScanner(
            controller: camera,
            onDetect: detect,
            errorBuilder: (context, error) => const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'تعذر فتح الكاميرا. اسمح بالوصول للكاميرا من إعدادات الجهاز، أو استخدم كود الربط يدويًا.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(error!, style: const TextStyle(color: Colors.red)),
          ),
      ],
    ),
  );
}
