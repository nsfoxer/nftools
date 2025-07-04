
import 'dart:typed_data';

import 'package:nftools/utils/nf_widgets.dart';

import '../../../src/bindings/bindings.dart';

class ImageSplitState {
  bool isLoading = false;
  // 原始图片
  Uint8List? originalImage;

  // 当前图片
  Uint8List? currentImage;
  // 预览图片
  Uint8List? previewImage;
  //
  bool isPreview = false;

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
    previewImage = null;
    controller.reset();
    isLoading = false;
    isPreview = false;
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
  path;

  MarkTypeMsg getDrawTypeMsg() {
    if (this == DrawStep.rect) {
      return MarkTypeMsg.rect;
    }
    return MarkTypeMsg.path;
  }
}