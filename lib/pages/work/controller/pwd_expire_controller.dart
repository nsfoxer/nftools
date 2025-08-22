import 'package:dio/dio.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:get/get.dart';
import 'package:nftools/pages/work/controller/work_controller.dart';
import 'package:nftools/pages/work/state/sms_limit_state.dart';

import '../../../utils/extension.dart';
import '../../../utils/log.dart';
import '../../../utils/utils.dart';

class PwdExpireController extends GetxController with GetxUpdateMixin {
  TextEditingController accountIdController = TextEditingController();

  late WorkController workController;
  Dio? dio;

  @override
  void onInit() {
    super.onInit();
    workController = Get.find<WorkController>();
  }

  @override
  void onReady() {
    super.onReady();
    if (!_setConfig()) {
      info("请先配置网络");
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

  void resetPwdExpireTime() async {
    final accountId = accountIdController.text.trim();
    accountIdController.text = accountId;
    if (accountId.isEmpty) {
      error("请输入账户id");
      return;
    }

    if (!_setConfig()) {
      return;
    }
    final rsp = await dio!.get(decrypt("/rpda-lolaepc-zapcletzy/tyypc/lat/cpdpeAhoPiatcp"), queryParameters: {
      "accountId": accountId,
    });
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
      info("重置$accountId成功");
      accountIdController.text = "";
    } else {
      error("重置$accountId失败");
    }
  }
}
