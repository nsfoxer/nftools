import 'dart:async';

import 'package:get/get.dart';
import 'package:nftools/pages/work/controller/work_controller.dart';
import 'package:nftools/pages/work/state/sms_limit_state.dart';
import 'package:dio/dio.dart';
import 'package:nftools/utils/utils.dart';

import '../../../utils/extension.dart';
import '../../../utils/log.dart';

class SmsLimitController extends GetxController with GetxUpdateMixin {
  late WorkController workController;
  SmsLimitState state = SmsLimitState();
  Dio? dio;

  Timer? _timer;

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
    _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
      debug("刷新数据 sms limit");
      refreshData();
    });
  }

  @override
  void onClose() {
    _timer?.cancel();
    super.onClose();
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
    final rsp = await dio!.get(decrypt("/rpda-lolaepc-zapcletzy/tyypc/lat/dxdNzfye"));
    if (rsp.statusCode != 200) {
      error("请求失败 请检查网络配置\n响应状态码: ${rsp.statusCode}");
      return;
    }
    final data = SmsLimitResponse.fromJson(rsp.data);
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

  void deleteSmsLimit(String phone) async {
    final rsp = await dio!.delete(decrypt("/rpda-lolaepc-zapcletzy/tyypc/lat/dxdNzfye"), queryParameters: {"phone": phone});
    if (rsp.statusCode != 200) {
      error("请求失败 请检查网络配置\n响应状态码: ${rsp.statusCode}");
      return;
    }
    final data = BoolResponse.fromJson(rsp.data);
    if (!data.success) {
      error("请求失败: ${data.msg}");
      return;
    }
    if (data.data) {
      info("删除$phone成功");
      refreshData();
    } else {
      error("删除$phone失败");
    }

  }

}

