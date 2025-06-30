
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
  DrawStep step = DrawStep.rect;

  // 控制器
  NFImagePainterController controller;

  // 画笔宽度
  double painterWidth = 5.0;

  // 是否为新增涂抹 仅在path下使用
  bool isAddAreaMode = true;

  ImageSplitState(this.controller);


  void reset() {
    painterWidth = 5.0;
    step = DrawStep.rect;
    isAddAreaMode = true;
    originalImage = null;
    currentImage = null;
    resultImage = null;
    controller.reset();
    isLoading = false;
  }

  DrawType getDrawType() {
    if (step == DrawStep.rect) {
      return DrawType.rect;
    }
    return DrawType.path;
  }
}

enum DrawStep {
  rect,
  path
}