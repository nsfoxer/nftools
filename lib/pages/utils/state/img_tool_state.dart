import 'package:fluent_ui/fluent_ui.dart';
import 'package:meta/meta.dart';

import '../../../utils/utils.dart';
import '../controller/img_tool_controller.dart';

class ImgToolState {
  // 要处理的图片地址
  NFImage? srcImage;

  // 当前操作
  ImgToolEnum? operationEnum;

  // 矩形标注框
  AnnotationBox annotationBox = AnnotationBox.zero();

  // 输出图像
  NFImage? dstImage;

  // 是否正在处理
  bool isLoading = false;

  void reset({bool notResetOperation = false}) {
    srcImage = null;
    annotationBox = AnnotationBox.zero();
    dstImage = null;
    isLoading = false;
    if (!notResetOperation) {
      operationEnum = null;
    }
  }
}

/// 标注框
/// 标注框的起始坐标和结束坐标
/// 数据为img的相对坐标 取值为 [0,1]
@Immutable()
class AnnotationBox {
  final Offset startPosition;
  final Offset endPosition;

  const AnnotationBox({required this.startPosition, required this.endPosition});

  const AnnotationBox.zero() : this(startPosition: Offset.zero, endPosition: Offset.zero);

}