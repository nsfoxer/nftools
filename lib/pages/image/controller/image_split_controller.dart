import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:get/get.dart';
import 'package:nftools/utils/extension.dart';
import 'package:nftools/utils/nf_widgets.dart';
import 'package:pasteboard/pasteboard.dart';

import '../../../utils/log.dart';
import '../../../utils/utils.dart';
import '../state/Image_split_state.dart';

/// 图片分割控制器
class ImageSplitController extends GetxController with GetxUpdateMixin {
  late ImageSplitState state;

  @override
  void onInit() {
    super.onInit();
    state =  ImageSplitState(NFImagePainterController(width: state.painterWidth, endType: _listenDrawEnd, startType:  _listenDrawStart));
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
    state.reset();
    update();
  }

  void _listenDrawStart(DrawType startType) {
    if (state.step == 0) {
      state.controller.clearData();
    }
  }

  void _listenDrawEnd(DrawType endType) {
    if (state.step == 0) {
      // 绘制矩形完成
      state.controller.limitTypeNum(DrawType.rect, 1);
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
    _startRect();
    _endLoading();
  }

  void _startRect() {
    state.controller.changeDrawType(DrawType.rect, 3, Colors.grey);
  }

  void changePainterWidth(bool isAdd) {
    var value = state.painterWidth;
    if (isAdd) {
      value += 1;
    } else {
      value -= 1;
    }
    value = value.clamp(1, 20);
    if (value == state.painterWidth)
      return;
    state.painterWidth = value;
    state.controller.changeDrawType(state.getDrawType(), value, Colors.grey);
    update();
  }

}
