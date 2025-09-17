import 'dart:io';
import 'dart:typed_data';

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
        width: 5, enableMouse: true, endType: _listenDrawEnd, startType: _listenDrawStart));
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
    state.originalImage = image;
    state.currentImage = image;
    state.controller.setImageProvider(FileImage(file));
    await $api2.createImage(image);
    _startRect();
    _endLoading();
  }

  /// 复制结果至剪贴板
  void copyResult() async {
    if (state.previewImage == null) {
      error("暂未获取到预览图像");
      return;
    }
    await Pasteboard.writeImage(state.previewImage!);
    info("复制图像成功");
  }

  /// 下载结果
  void saveResult() async {
    if (state.previewImage == null) {
      error("暂未获取到预览图像");
      return;
    }
    FilePicker.platform.saveFile(
      dialogTitle: "保存图像",
      type: FileType.image,
      bytes: state.previewImage!,
      fileName: "1.png"
    );
    info("保存图像成功");
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
    File file = File(path);
    final bytes = await file.readAsBytes();

    // 加载图像
    reset();
    _startLoading();
    state.originalImage = bytes;
    state.currentImage = bytes;
    state.controller.setImageProvider(MemoryImage(bytes));
    await $api2.createImage(bytes);
    _startRect();
    _endLoading();
  }

  void _startRect() {
    state.controller.changeDrawType(
        DrawType.rect, state.painterWidth, _getColor(DrawStep.rect, state.isAddAreaMode));
  }

  void changePainterWidth(double value) {
    if (value == state.painterWidth) {
      return;
    }
    state.painterWidth = value;
    state.controller.changeDrawType(
        state.getDrawType(), value, _getColor(state.step, state.isAddAreaMode));
    update();
  }

  Future<void> next() async {
    if (_imgCount == 0) {
      warn("请先做标记");
      return;
    }
    _startLoading();

    var oldType = DrawStep.path;
    if (state.step == DrawStep.rect) {
      oldType = DrawStep.rect;
      state.step = DrawStep.path;
      state.controller.changeDrawType(
          DrawType.path, state.painterWidth, _getColor(DrawStep.path, state.isAddAreaMode));
    }

    final markImage = await _saveCanvas();
    final result = await $api2.handleImage(ImageSplitReqMsg(
        markImage: DataMsg(value: markImage),
        markType:  oldType.getDrawTypeMsg(),
        addColor: color2Msg(_getColor(oldType, true)),
        delColor: color2Msg(_getColor(oldType, false))));

    _imgCount = 0;
    state.currentImage = result;
    state.controller.clearData();
    state.controller.setImageProvider(MemoryImage(result));
    state.previewImage = null;

    _endLoading();
  }

  Color _getColor(DrawStep step, bool isAddArea) {
    if (step == DrawStep.rect) {
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
        _getColor(state.step, state.isAddAreaMode));
    update();
  }

  // 撤销
  void redo() {
    _imgCount -= 1;
    if (_imgCount < 0) {
      _imgCount = 0;
    }
    state.controller.redo();
  }

  Future<Uint8List> _saveCanvas() async {
    final (boardSize, imgRect, bytes) = await state.controller.saveCanvas();
    if (bytes == null) {
      return Uint8List(0);
    }
    SplitImageMsg msg = SplitImageMsg(
      image: DataMsg(value: bytes),
      rect: RectMsg(
          leftX: imgRect.left,
          leftY: imgRect.top,
          width: imgRect.width,
          height: imgRect.height),
    );
    return  await $api.splitImage(msg);
  }

  ColorMsg color2Msg(Color color) {
    return ColorMsg(
        r: (color.r * 255.0).round() & 0xff,
        g: (color.g * 255.0).round() & 0xff,
        b: (color.b * 255.0).round() & 0xff,
        a: (color.a * 255.0).round() & 0xff);
  }

  /// 预览
  void preview() async{
    state.isPreview = !state.isPreview;
    if (!state.isPreview) {
      state.controller.setImageProvider(MemoryImage(state.currentImage!));
      update();
      return;
    }
    _startLoading();
    if (_imgCount != 0) {
      await next();
    }
    state.previewImage ??= await $api2.previewImage();
    _endLoading();
  }

  Color? getColor() {
    return _getColor(state.step, state.isAddAreaMode);
  }
}
