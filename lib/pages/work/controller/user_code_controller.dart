import 'package:get/get.dart';
import 'package:nftools/pages/work/controller/work_controller.dart';
import 'package:nftools/pages/work/state/user_code_state.dart';
import 'package:dio/dio.dart';
import 'package:nftools/utils/utils.dart';

import '../../../utils/extension.dart';
import '../../../utils/log.dart';

class UserCodeController extends GetxController with GetxUpdateMixin {
  late WorkController workController;
  UserCodeState state = UserCodeState();
  Dio? dio;

  @override
  void onInit() {
    super.onInit();

    workController = Get.find<WorkController>();
  }

  @override
  void onReady() {
    super.onReady();
    if (_setConfig()) {
      refreshData();
    }
  }

  bool _setConfig() {
    dio = workController.getDio();
    if (dio == null) {
      error("请先配置网络");
      return false;
    }
    return true;
  }


  void refreshData() async {
    // 1. 获取网络配置
    if (dio == null) {
      if (!_setConfig()) {
        return;
      }
    }

    // 2. 发送请求
    _startLoading();
    final rsp = await dio!.get(decrypt("/rpda-lolaepc-zapcletzy/tyypc/lat/fdpcNzop"));
    if (rsp.statusCode != 200) {
      error("请求失败 请检查网络配置");
      return;
    }
    final data = UserCodeResponse.fromJson(rsp.data);
    if (!data.success) {
      error("请求失败: ${data.msg}");
      return;
    }
    state.data = data.data;
    _endLoading();
  }

  void _startLoading() {
    state.isLoading = true;
    update();
  }
  void _endLoading() {
    state.isLoading = false;
    update();
  }


}

