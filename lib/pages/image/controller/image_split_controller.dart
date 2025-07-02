import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:get/get.dart';
import 'package:nftools/utils/extension.dart';
import 'package:nftools/utils/nf_widgets.dart';
import 'package:pasteboard/pasteboard.dart';

import '../../../api/utils.dart' as $api;
import '../../../api/image_split.dart' as $api2;
import '../../../src/bindings/bindings.dart';
import '../../../utils/log.dart';
import '../../../utils/utils.dart';
import '../state/Image_split_state.dart';

/// 图片分割控制器
class ImageSplitController extends GetxController with GetxUpdateMixin {
  late ImageSplitState state;

  int _imgCount = 0;

  @override
  void onInit() {
    super.onInit();
    state = ImageSplitState(NFImagePainterController(
        width: 5, endType: _listenDrawEnd, startType: _listenDrawStart));
  }

  /// 从剪贴板中获取图像
  void setPasteImg() async {
    // 保存图像到临时文件
    final image = await Pasteboard.image;
    if (image == null || image.isEmpty) {
      warn("未获取到剪贴板中图像");
      return;
    }
    reset();
    _startLoading();
    final file = await saveBytesToTempFile(image, fileExtension: "png");
    state.originalImage = file.path;
    state.currentImage = file.path;
    state.controller.setImageProvider(FileImage(file));
    await $api2.createImage(file.path);
    _startRect();
    _endLoading();
  }

  /// 复制结果至剪贴板
  void copyResult() async {
    // final file = File(state.currentImage!.originalPath);
    // final bytes = await file.readAsBytes();
    // Pasteboard.writeImage(bytes);
    // info("复制图像成功");
  }

  /// 开始加载
  void _startLoading() {
    state.isLoading = true;
    update();
  }

  /// 结束加载
  void _endLoading() {
    state.isLoading = false;
    update();
  }

  void reset() {
    _imgCount = 0;
    state.reset();
    update();
  }

  void _listenDrawStart(DrawType startType) {
    if (state.step == DrawStep.rect) {
      state.controller.clearData();
    }
  }

  void _listenDrawEnd(DrawType endType) {
    _imgCount++;
    debug("end _imgCount: $_imgCount");
    if (state.step == DrawStep.rect) {
      // 绘制矩形完成
      state.controller.limitTypeNum(DrawType.rect, 1);
      _imgCount = 1;
      return;
    }
  }

  /// 从文件中获取图像
  void setFileImg() async {
    FilePickerResult? result =
        await FilePicker.platform.pickFiles(type: FileType.image);
    final path = result?.files.single.path;
    if (path == null) {
      return;
    }

    // 加载图像
    reset();
    _startLoading();
    state.originalImage = path;
    state.currentImage = path;
    state.controller.setImageProvider(FileImage(File(path)));
    await $api2.createImage(path);
    _startRect();
    _endLoading();
  }

  void _startRect() {
    state.controller.changeDrawType(
        DrawType.rect, state.painterWidth, _getColor(state.isAddAreaMode));
  }

  void changePainterWidth(double value) {
    if (value == state.painterWidth) {
      return;
    }
    state.painterWidth = value;
    state.controller.changeDrawType(
        state.getDrawType(), value, _getColor(state.isAddAreaMode));
    update();
  }

  void next() async {
    if (_imgCount == 0) {
      warn("请先做标记");
      return;
    }
    _startLoading();
    if (state.step == DrawStep.rect) {
      // 绘制矩形完成
      final markImage = await _saveCanvas();
      // 处理图像
      debug("markImage: $markImage");
      final result = await $api2.handleImage(ImageSplitReqMsg(
          markImage: markImage,
          markType: MarkTypeMsg.rect,
          addColor: color2Msg(_getColor(true)),
          delColor: color2Msg(_getColor(false))));
      state.step = DrawStep.path;
      state.controller.clearData();
      state.controller.changeDrawType(
          DrawType.path, state.painterWidth, _getColor(state.isAddAreaMode));
      _imgCount = 0;
      state.currentImage = result;
      state.controller.setImageProvider(FileImage(File(result)));
    } else if (state.step == DrawStep.path) {
      // 绘制完成
      final markImage = await _saveCanvas();
      final result = await $api2.handleImage(ImageSplitReqMsg(
          markImage: markImage,
          markType: MarkTypeMsg.path,
          addColor: color2Msg(_getColor(true)),
          delColor: color2Msg(_getColor(false))));
      _imgCount = 0;
      state.controller.clearData();
      state.currentImage = result;
      state.controller.setImageProvider(FileImage(File(result)));
      debug("result: $result");
    }

    _endLoading();
  }

  Color _getColor(bool isAddArea) {
    if (state.step == DrawStep.rect) {
      return Colors.orange;
    }
    if (isAddArea) {
      return Colors.green.withValues(alpha: 0.8);
    }
    return Colors.grey.withValues(alpha: 0.8);
  }

  void changeAreaMode() {
    state.isAddAreaMode = !state.isAddAreaMode;
    state.controller.changeDrawType(state.getDrawType(), state.painterWidth,
        _getColor(state.isAddAreaMode));
    update();
  }

  // 撤销
  void redo() {
    _imgCount -= 1;
    if (_imgCount < 0) {
      _imgCount = 0;
    }
    debug("_imgCount: $_imgCount");
    state.controller.redo();
  }

  Future<String> _saveCanvas() async {
    final tmpFile = await getTempFilePath(fileExtension: "png");
    final (boardSize, imgRect) = await state.controller.saveCanvas(tmpFile);
    SplitImageMsg msg = SplitImageMsg(
      image: tmpFile,
      rect: RectMsg(
          leftX: imgRect.left,
          leftY: imgRect.top,
          width: imgRect.width,
          height: imgRect.height),
    );
    return await $api.splitImage(msg);
  }

  ColorMsg color2Msg(Color color) {
    return ColorMsg(
        r: (color.r * 255.0).round() & 0xff,
        g: (color.g * 255.0).round() & 0xff,
        b: (color.b * 255.0).round() & 0xff,
        a: (color.a * 255.0).round() & 0xff);
  }
}
