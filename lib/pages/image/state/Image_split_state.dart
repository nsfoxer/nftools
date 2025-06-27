
import 'package:fluent_ui/fluent_ui.dart';
import 'package:nftools/utils/nf_widgets.dart';

class ImageSplitState {
  bool isLoading = false;
  // 原始图片
  String? originalImage;

  // 当前图片
  String? currentImage;

  // 分割结果图片
  String? resultImage;

  // 当前分割步骤
  int step = 0;

  // 控制器
  NFImagePainterController controller;

  // 画笔宽度
  double painterWidth = 1.0;

  ImageSplitState(this.controller);


  void reset() {
    originalImage = null;
    currentImage = null;
    resultImage = null;
    step = 0;
    controller.reset();
    isLoading = false;
  }

  DrawType getDrawType() {
    if (step == 0) {
      return DrawType.rect;
    }

    return DrawType.path;
  }

}