import 'package:fluent_ui/fluent_ui.dart';
import 'package:meta/meta.dart';

import '../../../utils/utils.dart';
import '../controller/img_tool_controller.dart';

class ImgToolState {
  // 要处理的图片地址
  NFImage? srcImage;

  // 当前操作
  ImgToolEnum? operationEnum;

  // 屏幕坐标矩形框
  Rect annotationBoxRect = Rect.zero;

  // 输出图像
  NFImage? dstImage;

  // 是否正在处理
  bool isLoading = false;

  void reset({bool notResetOperation = false}) {
    srcImage = null;
    dstImage = null;
    annotationBoxRect = Rect.zero;
    isLoading = false;
    if (!notResetOperation) {
      operationEnum = null;
    }
  }
}