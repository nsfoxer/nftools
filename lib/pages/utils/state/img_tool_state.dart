import 'package:fluent_ui/fluent_ui.dart';
import 'package:meta/meta.dart';

import '../controller/img_tool_controller.dart';

class ImgToolState {
  // 要处理的图片地址
  ImgInfo? srcImgInfo;

  // 当前操作
  ImgToolEnum? imgToolEnum;

  // 矩形标注框
  AnnotationBox annotationBox = AnnotationBox.zero();
}

@Immutable()
class ImgInfo {
  // 图片路径
  final ImageProvider<Object> img;
  // 图片信息
  final ImageInfo info;

  const ImgInfo({required this.img, required this.info});
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