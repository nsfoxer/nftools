import 'package:dio/dio.dart';
import 'package:get/get_state_manager/src/simple/get_controllers.dart';
import 'package:nftools/pages/work/state/work_state.dart';
import 'package:nftools/utils/extension.dart';
import 'package:nftools/api/utils.dart' as $api;

class WorkController extends GetxController with GetxUpdateMixin {
  WorkState workState = WorkState();
  static final String _workUrl = "WorkUrl";
  static final String _workToken = "WorkToken";
  static final String _workKey = "WorkKey";


  @override
  void onReady() async {
    await _init();
    super.onReady();
  }

  Future<void> _init() async {
    workState.urlTextController.text = await getData(_workUrl);
    workState.tokenTextController.text = await getData(_workToken);
    workState.keyTextController.text = await getData(_workKey);
    _setIsConfigPage();
    update();
  }

  Future<String> getData(String key) async {
    final data = await $api.getData(key);
    if (data == null) {
      return "";
    }
    return data;
  }

  void _setIsConfigPage() {
    if (workState.urlTextController.text.isNotEmpty &&
        workState.tokenTextController.text.isNotEmpty &&
        workState.keyTextController.text.isNotEmpty) {
      workState.isConfigPage = false;
    }
  }

  Future<bool> saveConfig() async {
    _setIsConfigPage();
    if (workState.isConfigPage) {
      return false;
    }
    await $api.setData(_workUrl, workState.urlTextController.text);
    await $api.setData(_workToken, workState.tokenTextController.text);
    await $api.setData(_workKey, workState.keyTextController.text);
    update();
    return true;
  }

  void startConfig() {
    workState.isConfigPage = true;
    update();
  }

  /// 获取工作网络配置
  Dio? getDio() {
    _setIsConfigPage();
    if (workState.isConfigPage) {
      return null;
    }
    return Dio(
      BaseOptions(
        baseUrl: workState.urlTextController.text,
        headers: {
          "token": workState.tokenTextController.text,
          "innerKey": workState.keyTextController.text,
          "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/139.0.0.0 Safari/537.36",
        },
        validateStatus: (status) {
          if (status == null) {
            return false;
          }
          return status < 600;
        },
      ),
    );
  }

}
