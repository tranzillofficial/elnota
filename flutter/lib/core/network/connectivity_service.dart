import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:get/get.dart';
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';

class ConnectivityService extends GetxService {
  static ConnectivityService get to => Get.find<ConnectivityService>();

  final RxBool isOnline = false.obs;
  StreamSubscription<List<ConnectivityResult>>? _connSub;
  StreamSubscription<InternetStatus>? _statusSub;

  final _reconnectStreamController = StreamController<void>.broadcast();
  Stream<void> get onReconnect => _reconnectStreamController.stream;

  @override
  void onInit() {
    super.onInit();
    _initConnectivity();
  }

  Future<void> _initConnectivity() async {
    // Initial check
    final hasInternet = await InternetConnection().hasInternetAccess;
    isOnline.value = hasInternet;

    // Listen to network changes
    _statusSub = InternetConnection().onStatusChange.listen((status) {
      final wasOnline = isOnline.value;
      final connected = status == InternetStatus.connected;
      isOnline.value = connected;

      if (!wasOnline && connected) {
        _reconnectStreamController.add(null);
      }
    });

    _connSub = Connectivity().onConnectivityChanged.listen((results) async {
      final hasNet = await InternetConnection().hasInternetAccess;
      final wasOnline = isOnline.value;
      isOnline.value = hasNet;
      if (!wasOnline && hasNet) {
        _reconnectStreamController.add(null);
      }
    });
  }

  @override
  void onClose() {
    _connSub?.cancel();
    _statusSub?.cancel();
    _reconnectStreamController.close();
    super.onClose();
  }
}
