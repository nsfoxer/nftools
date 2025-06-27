import 'dart:ui';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:nftools/utils/nf_widgets.dart';

class ImageSplitState {
  // 原始图片路径
  String? originalImagePath;

  // 当前图片路径
  String? currentImagePath;

  // 当前分割步骤
  int step = 0;

  // 控制器
  NFImagePainterController controller = NFImagePainterController(DrawType.none, 0, Colors.transparent, null);

}