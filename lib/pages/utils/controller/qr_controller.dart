import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:easy_debounce/easy_debounce.dart';
import 'package:file_picker/file_picker.dart';
import 'package:get/get_state_manager/src/simple/get_controllers.dart';
import 'package:nftools/pages/utils/state/qr_encode_state.dart';
import 'package:nftools/src/bindings/signals/signals.dart';
import 'package:nftools/utils/utils.dart';
import 'package:pasteboard/pasteboard.dart';

import '../../../common/constants.dart';
import '../../../api/utils.dart' as $api;
import '../../../utils/extension.dart';
import '../../../utils/log.dart';

class QrController extends GetxController with GetxUpdateMixin {
  QrEncodeState state = QrEncodeState();

  String _lastText = "";

  @override
  void onInit() {
    super.onInit();
    _init();
  }

  void _init() async {
    // 初始化监听器
    state.codeLineEditingController.addListener(() {
      if (!state.isData2Qr ||
          _lastText == state.codeLineEditingController.text) {
        return;
      }
      EasyDebounce.debounce(
          PageWidgetNameConstant.qrCodeText, const Duration(milliseconds: 1000),
          () {
        _lastText = state.codeLineEditingController.text;
        _generateText(state.codeLineEditingController.text);
      });
    });

    // 如果剪贴板有文本，则自动设置
    final text = await Pasteboard.text;
    if (text != null && text.isNotEmpty) {
      state.codeLineEditingController.text = text;
    }

    state.imageFocus.requestFocus();
  }

  void _generateText(String text) async {
    state.filePath = null;
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
    state.filePath = path;
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
    state.codeLineEditingController.dispose();
    super.onClose();
  }

  // 解码粘贴板的图片
  void decodePasteboardImage() async {
    final image = await Pasteboard.image;
    if (image == null || image.isEmpty) {
      warn("未获取到剪贴板中图像");
      return;
    }
    // 压缩图片
    final file = await saveBytesToTempFile(image, fileExtension: "png");
    _compressPic(file.path);
    _detectImage(image);
  }

  void _detectImage(Uint8List imageData) async {
    state.imageDataForDecodeShow = null;
    state.codeLineEditingController.text = "";
    state.qRData = null;
    state.isLoading = true;
    update();
    final QrCodeDataMsgList data;
    try {
      data = await $api.detectQrCode(imageData);
    } catch (e) {
      state.isLoading = false;
      warn("识别二维码失败: $e");
      update();
      return;
    }
    state.qRData = data;
    state.isLoading = false;
    // 如果只有一个二维码，则直接解析
    if (data.value.isEmpty) {
      info("未识别到二维码");
    } else if (data.value.length == 1) {
      handleQr(data.value[0]);
    }
    update();
  }

  // 切换类型 文本转图 图转文本
  void switchType() {
    state.isData2Qr = !state.isData2Qr;
    reset();
  }

  // 解析图片
  void handleQr(QrCodeDataMsg e) {
    // 1. 清空数据
    state.codeLineEditingController.text = "";

    // 2. 尝试转换数据为字符串
    state.fileData = e.data;
    try {
      // 转换为字符串
      final text = utf8.decode(e.data);
      state.codeLineEditingController.text = text;
    } catch (ignored) {
      // 转换为文件
    }
    update();
  }

  void handleFile() async {
    // 文件转换为二维码
    if (state.isData2Qr) {
      final path = await _getLocalFile(FileType.any, null);
      if (path == null) {
        return;
      }
      generateFile(path);
      return;
    }

    // 二维码保存至文件
    final path = await _getLocalDirectory();
    if (path == null) {
      return;
    }
    // 按当前时间戳创建临时文件
    final filePath = "$path/二维码识别-${DateTime.now().millisecondsSinceEpoch}.txt";
    final file = File(filePath);
    await file.writeAsBytes(state.fileData);
    state.filePath = filePath;
    info("保存文件至: ${file.path}");
    update();
  }

  // 获取本地文件
  Future<String?> _getLocalFile(
      FileType fileType, List<String>? allowedExtensions) async {
    FilePickerResult? result = await FilePicker.platform
        .pickFiles(type: fileType, allowedExtensions: allowedExtensions);
    return result?.files.single.path;
  }

  // 获取本地目录
  Future<String?> _getLocalDirectory() async {
    return await FilePicker.platform.getDirectoryPath();
  }

  // 重置
  void reset() {
    state.imageData = Uint8List(0);
    state.codeLineEditingController.text = "";
    _lastText = "";
    state.fileData = [];
    state.filePath = null;
    state.imageDataForDecodeShow = null;
    update();
  }

  // 探测本地图片的二维码
  void readImage() async {
    final path = await _getLocalFile(
        FileType.custom, ["webp", "jpg", "jpeg", "png", "bmp", "ico"]);
    if (path == null) {
      return;
    }
    final file = File(path);
    final bytes = await file.readAsBytes();
    _compressPic(path);
    _detectImage(bytes);
  }

  void _compressPic(String localPic) async{
    try {
      final result = await $api.compressLocalFile(localPic, 800, 600);
      state.imageDataForDecodeShow = result.localFile;
    } catch (e) {
      warn("压缩图片失败: $e");
      state.imageDataForDecodeShow = localPic;
    } finally {
      update();
    }
  }
}
