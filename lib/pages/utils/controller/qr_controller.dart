
import 'dart:typed_data';

import 'package:easy_debounce/easy_debounce.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:get/get_state_manager/src/simple/get_controllers.dart';
import 'package:nftools/pages/utils/state/qr_encode_state.dart';
import 'package:pasteboard/pasteboard.dart';

import '../../../common/constants.dart';
import '../../../api/utils.dart' as $api;

class QrController extends GetxController {
  QrEncodeState state = QrEncodeState();

  String _lastText = "";

  @override
  void onInit() {
    debugPrint("messageinit =======================");
    super.onInit();
    _init();
    state.codeLineEditingController.addListener(() {
      if (_lastText == state.codeLineEditingController.text) {
        return;
      }
      EasyDebounce.debounce(PageWidgetNameConstant.qrCodeText, const Duration(milliseconds: 1000), () {
        _lastText = state.codeLineEditingController.text;
        _generateText(state.codeLineEditingController.text);
      });
    });
  }

  void _init() async {
    // 初始化监听器
    state.codeLineEditingController.addListener(() {
      if (_lastText == state.codeLineEditingController.text) {
        return;
      }
      EasyDebounce.debounce(PageWidgetNameConstant.qrCodeText, const Duration(milliseconds: 1000), () {
        _lastText = state.codeLineEditingController.text;
        _generateText(state.codeLineEditingController.text);
      });
    });

    // 如果剪贴板有文本，则自动设置
    final text = await Pasteboard.text;
    if (text != null && text.isNotEmpty) {
      state.codeLineEditingController.text = text;
    }
  }

  void _generateText(String text) async {
    // 无数据
    if (text.isEmpty) {
      state.imageData = Uint8List(0);
      update();
      return;
    }
    // 有数据
    state.isLoading = true;
    update();
    try {
      state.imageData = await $api.genTextQrCode(text);
    } finally {
      state.isLoading = false;
      update();
    }
  }

  void generateFile(String path) async {
    state.isLoading = true;
    update();
    try {
      state.imageData = await $api.genFileQrCode(path);
    } finally {
      state.isLoading = false;
      update();
    }
  }

  @override
  void onClose() {
    debugPrint("message dispose =======================");
    state.codeLineEditingController.dispose();
    super.onClose();
  }
}