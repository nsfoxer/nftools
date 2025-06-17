import 'dart:io';
import 'dart:math';

import 'package:file_picker/file_picker.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:get/get_state_manager/src/simple/get_controllers.dart';
import 'package:nftools/utils/log.dart';
import 'package:nftools/utils/utils.dart';
import 'package:pasteboard/pasteboard.dart';

import '../../../api/utils.dart' as $api;
import '../../../common/constants.dart';
import '../../../utils/extension.dart';
import '../state/img_tool_state.dart';

class ImgToolController extends GetxController with GetxUpdateMixin {
  final state = ImgToolState();

  // 图像在屏幕上的坐标
  Rect _imgRect = Rect.zero;
  // 是否正在绘制矩形
  bool _isDrawing = false;


  @override
  void onReady() {
    super.onReady();
  }

  /// 设置源图片
  Future<void> _setSrcImg(File imgFile) async {
    final img = FileImage(imgFile);
    final imgInfo = await getImageInfoFromProvider(img);
    state.srcImgInfo = ImgInfo(img: img, info: imgInfo);
  }

  /// 当前操作
  void operate(ImgToolEnum imgToolEnum) {
    switch (imgToolEnum) {
      case ImgToolEnum.backgroundSplit:
        state.imgToolEnum = ImgToolEnum.backgroundSplit;
        break;
    }
    update();
  }

  // 计算图像在容器中的位置和尺寸（考虑BoxFit.contain）
  void resetImageRect(double containerWidth, double containerHeight,
      double imageWidth, double imageHeight) {
    final containerRatio = containerWidth / containerHeight;
    final imageRatio = imageWidth / imageHeight;

    double width, height, left, top;

    if (containerRatio > imageRatio) {
      // 图像高度占满容器，宽度留边距
      height = containerHeight;
      width = height * imageRatio;
      left = (containerWidth - width) / 2;
      top = 0;
    } else {
      // 图像宽度占满容器，高度留边距
      width = containerWidth;
      height = width / imageRatio;
      left = 0;
      top = (containerHeight - height) / 2;
    }
    _imgRect = Rect.fromLTWH(left, top, width, height);
  }

  /// 设置画矩形的结束位置
  /// @param endPosition 结束位置
  void _setDrawEndRect(Offset endPosition) {
    final position = _screenToImageRelativePosition(endPosition);
    state.annotationBox = AnnotationBox(startPosition: state.annotationBox.startPosition, endPosition: position);
    update([PageWidgetNameConstant.drawRect]);
  }

  /// 处理图像的拖动开始事件
  void handlePanStart(DragStartDetails details) {
    final position = details.localPosition;
    // 判断是否在图像区域内
    if (!_imgRect.contains(position)) {
      state.annotationBox = AnnotationBox.zero();
      return;
    }
    _isDrawing = true;
    // 记录初始位置
    final startOffest = _screenToImageRelativePosition(position);
    state.annotationBox = AnnotationBox(
      startPosition: startOffest,
      endPosition: startOffest,
    );
  }
  /// 处理图像的拖动更新事件
  void handlePanUpdate(DragUpdateDetails details) {
    if (!_isDrawing) {
      state.annotationBox = AnnotationBox.zero();
      return;
    }
    _setDrawEndRect(details.localPosition);
  }

  /// 处理图像的拖动结束事件
  void handlePanEnd(DragEndDetails details) {
    if (!_isDrawing) {
      state.annotationBox = AnnotationBox.zero();
      return;
    }
    _isDrawing = false;
    _setDrawEndRect(details.localPosition);
  }

  /// 计算屏幕坐标在图像坐标中的位置
  Offset _screenToImageRelativePosition(Offset screenOffset) {
    final x = (screenOffset.dx - _imgRect.left) / _imgRect.width;
    final y = (screenOffset.dy - _imgRect.top) / _imgRect.height;
    return Offset(x.clamp(0.0, 1.0), y.clamp(0.0, 1.0));
  }

  Offset _imageRelativePositionToScreen(Offset annotationOffset) {
    if (_imgRect.isEmpty) {
      return Offset.zero;
    }
    final x = _imgRect.left + annotationOffset.dx * _imgRect.width;
    final y = _imgRect.top + annotationOffset.dy * _imgRect.height;
    return Offset(x, y);
  }

  /// 转换注释框为屏幕坐标
  Rect annotationBoxToScreenRect() {
    if (state.annotationBox.startPosition == Offset.zero || state.annotationBox.endPosition == Offset.zero) {
      return Rect.zero;
    }
    final startPosition = _imageRelativePositionToScreen(state.annotationBox.startPosition);
    final endPosition = _imageRelativePositionToScreen(state.annotationBox.endPosition);
    final left = min(startPosition.dx, endPosition.dx);
    final top = min(startPosition.dy, endPosition.dy);
    final width = (startPosition.dx - endPosition.dx).abs();
    final height = (startPosition.dy -endPosition.dy).abs();
    final result = Rect.fromLTWH(left, top, width, height);
    if (isRectTooSmall(result, 10)) {
      return Rect.zero;
    }
    return result;
  }


  /// 从剪贴板中获取图像
  void setPasteImg() async {
    // 保存图像到临时文件
    final image = await Pasteboard.image;
    if (image == null || image.isEmpty) {
      warn("未获取到剪贴板中图像");
      return;
    }
    final file = await saveBytesToTempFile(image, fileExtension: "png");
    _setSrcImg(file);

    update();
  }

  /// 从文件中获取图像
  void setFileImg(TapUpDetails details) async {
    debug("setFileImg");
    if (!_imgRect.isEmpty && _imgRect.contains(details.localPosition)) {
      return;
    }
    FilePickerResult? result = await FilePicker.platform
        .pickFiles(type: FileType.image);
    final path = result?.files.single.path;
    if (path == null) {
      return;
    }
    _setSrcImg(File(path));
    update();
  }

  getCursor() {
    switch (state.imgToolEnum) {
      case ImgToolEnum.backgroundSplit:
        return SystemMouseCursors.precise;
        default:
          return SystemMouseCursors.basic;
    }
  }


  /// 操作完成后的处理
  void convert() {
    switch (state.imgToolEnum) {
      case ImgToolEnum.backgroundSplit:
        _convertBackgroundSplit();
        break;
      default:
        return;
    }
  }

  /// 背景分割
  void _convertBackgroundSplit() async {
    if (state.srcImgInfo == null) {
      info("未选择图片");
      return;
    }
    final rect = annotationBoxToScreenRect();
    if (isRectTooSmall(rect, 10)) {
      info("请标注主体区域");
      return;
    }
    // todo

  }

}

enum ImgToolEnum {
  backgroundSplit("背景去除"),
  ;

  const ImgToolEnum(this.desc);

  final String desc;
}
