import 'dart:async';
import '../api/utils.dart' as $api;

class GlobalData {
  const GlobalData();

  // 网络状态
  static bool isConnected = false;

  static void initGlobalData() {
    isConnected = $api.networkStatus();

    Timer.periodic(const Duration(seconds: 30), (timer) async {
      isConnected = await $api.networkStatus();
    });
  }
}
