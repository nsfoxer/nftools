import 'dart:io';
import 'dart:math';

import 'package:file_picker/file_picker.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:get/get_state_manager/src/simple/get_controllers.dart';
import 'package:nftools/src/bindings/bindings.dart';
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
  _OperationEnum? _operationEnum;

  /// 当前操作
  void operate(ImgToolEnum imgToolEnum) {
    resetSelf();
    switch (imgToolEnum) {
      case ImgToolEnum.backgroundSplit:
        state.operationEnum = ImgToolEnum.backgroundSplit;
        break;
    }
    update();
  }

  /// 重置源图像
  /// 计算图像在容器中的位置和尺寸（考虑BoxFit.contain）
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
    final rect = state.annotationBoxRect;
    final left = min(rect.left, endPosition.dx).clamp(_imgRect.left, _imgRect.right);
    final top = min(rect.top, endPosition.dy).clamp(_imgRect.top, _imgRect.bottom);
    final right = max(rect.right, endPosition.dx).clamp(_imgRect.left, _imgRect.right);
    final bottom = max(rect.bottom, endPosition.dy).clamp(_imgRect.top, _imgRect.bottom);
    state.annotationBoxRect = Rect.fromLTRB(left, top, right, bottom);
    update([PageWidgetNameConstant.drawRect]);
  }

  final _dotSize = 10.0;

  (Rect, Rect, Rect, Rect) annotationBoxRectToDot() {
    if (state.annotationBoxRect.isEmpty) {
      return (Rect.zero, Rect.zero, Rect.zero, Rect.zero);
    }
    final width = state.annotationBoxRect.width;
    final height = state.annotationBoxRect.height;
    final dx = state.annotationBoxRect.left;
    final dy = state.annotationBoxRect.top;
    final topRect = Rect.fromCenter(
        center: Offset(dx + width / 2, dy), width: _dotSize, height: _dotSize);
    final bottomRect = Rect.fromCenter(
        center: Offset(dx + width / 2, dy + height),
        width: _dotSize,
        height: _dotSize);
    final leftRect = Rect.fromCenter(
        center: Offset(dx, dy + height / 2), width: _dotSize, height: _dotSize);
    final rightRect = Rect.fromCenter(
        center: Offset(dx + width, dy + height / 2),
        width: _dotSize,
        height: _dotSize);
    return (topRect, bottomRect, leftRect, rightRect);
  }

  /// 处理图像的拖动开始事件
  void handlePanStart(DragStartDetails details) {
    final position = details.localPosition;
    // 判断是否在图像区域内
    if (!_imgRect.contains(position)) {
      state.annotationBoxRect = Rect.zero;
      return;
    }
    debug("start");
    // 判断是否在标注框dot区域内
    final (dotTopRect, dotBottomRect, dotLeftRect, dotRightRect) =
        annotationBoxRectToDot();
    if (dotLeftRect.contains(position)) {
      _operationEnum = _OperationEnum.left;
    } else if (dotRightRect.contains(position)) {
      _operationEnum = _OperationEnum.right;
    } else if (dotTopRect.contains(position)) {
      _operationEnum = _OperationEnum.top;
    } else if (dotBottomRect.contains(position)) {
      _operationEnum = _OperationEnum.bottom;
    } else {
      // 不在标注框dot区域内，开始绘制矩形
      _operationEnum = null;
      _isDrawing = true;
      // 记录初始位置
      state.annotationBoxRect = Rect.fromLTWH(position.dx, position.dy, 0, 0);
      debug("开始绘制矩形");
    }
  }

  /// 处理图像的拖动更新事件
  void handlePanUpdate(DragUpdateDetails details) {
    if (_handleDot(details.localPosition)) {
      update([PageWidgetNameConstant.drawRect]);
      return;
    }

    if (!_isDrawing) {
      state.annotationBoxRect = Rect.zero;
      return;
    }
    _setDrawEndRect(details.localPosition);
  }

  // 是否已处理
  bool _handleDot(Offset position) {
    if (_operationEnum == null) {
      return false;
    }

    switch (_operationEnum) {
      case _OperationEnum.left:
        final dx =
            position.dx.clamp(_imgRect.left, state.annotationBoxRect.right);
        position = Offset(dx, position.dy);
        state.annotationBoxRect = Rect.fromLTWH(
            position.dx,
            state.annotationBoxRect.top,
            state.annotationBoxRect.width +
                state.annotationBoxRect.left -
                position.dx,
            state.annotationBoxRect.height);
        break;
      case _OperationEnum.right:
        final dx =
            position.dx.clamp(state.annotationBoxRect.left, _imgRect.right);
        state.annotationBoxRect = Rect.fromLTWH(
            state.annotationBoxRect.left,
            state.annotationBoxRect.top,
            dx - state.annotationBoxRect.left,
            state.annotationBoxRect.height);
        break;
      case _OperationEnum.top:
        final dy =
            position.dy.clamp(_imgRect.top, state.annotationBoxRect.bottom);
        state.annotationBoxRect = Rect.fromLTWH(
            state.annotationBoxRect.left,
            dy,
            state.annotationBoxRect.width,
            state.annotationBoxRect.height + state.annotationBoxRect.top - dy);
        break;
      case _OperationEnum.bottom:
        final dy =
            position.dy.clamp(state.annotationBoxRect.top, _imgRect.bottom);
        state.annotationBoxRect = Rect.fromLTWH(
            state.annotationBoxRect.left,
            state.annotationBoxRect.top,
            state.annotationBoxRect.width,
            dy - state.annotationBoxRect.top);
        break;
      default:
        break;
    }
    return true;
  }

  /// 处理图像的拖动结束事件
  void handlePanEnd(DragEndDetails details) {
    if (_handleDot(details.localPosition)) {
      _operationEnum = null;
      update([PageWidgetNameConstant.drawRect]);
      return;
    }

    _operationEnum = null;
    if (!_isDrawing) {
      state.annotationBoxRect = Rect.zero;
      return;
    }
    _isDrawing = false;
    _setDrawEndRect(details.localPosition);
  }

  /// 从剪贴板中获取图像
  void setPasteImg() async {
    // 保存图像到临时文件
    final image = await Pasteboard.image;
    if (image == null || image.isEmpty) {
      warn("未获取到剪贴板中图像");
      return;
    }
    reset(notResetOperation: true);
    _startLoading();
    final file = await saveBytesToTempFile(image, fileExtension: "png");
    state.srcImage = await NFImage.fromOriginalPath(file.path);
    _endLoading();
  }

  /// 从文件中获取图像
  void setFileImg(TapUpDetails details) async {
    debug("setFileImg");
    if (!_imgRect.isEmpty && _imgRect.contains(details.localPosition)) {
      return;
    }
    FilePickerResult? result =
        await FilePicker.platform.pickFiles(type: FileType.image);
    final path = result?.files.single.path;
    if (path == null) {
      return;
    }

    // 加载图像
    reset(notResetOperation: true);
    _startLoading();
    state.srcImage = await NFImage.fromOriginalPath(path);
    _endLoading();
  }

  getCursor() {
    switch (state.operationEnum) {
      case ImgToolEnum.backgroundSplit:
        return SystemMouseCursors.precise;
      default:
        return SystemMouseCursors.basic;
    }
  }

  /// 操作完成后的处理
  void convert() {
    switch (state.operationEnum) {
      case ImgToolEnum.backgroundSplit:
        _convertBackgroundSplit();
        break;
      default:
        warn("请先选择一个操作");
        return;
    }
  }

  /// 背景分割
  void _convertBackgroundSplit() async {
    debug("message: _convertBackgroundSplit");
    if (state.srcImage == null) {
      info("未选择图片");
      return;
    }
    final rect = state.annotationBoxRect;
    if (isRectTooSmall(rect, 10)) {
      info("请标注主体区域");
      return;
    }

    _startLoading();
    final imgRect = _annotationBoxToImageRelativeRect();
    debug("坐标: ${state.annotationBoxRect}");
    debug("坐标: ${_imgRect}");
    debug("比例坐标: $imgRect");
    final String result;
    try {
      result = await $api.splitBackground(SplitBackgroundImgMsg(
          srcImg: state.srcImage!.originalPath,
          leftX: imgRect.left,
          leftY: imgRect.top,
          width: imgRect.width,
          height: imgRect.height));
      state.dstImage = await NFImage.fromOriginalPath(result);
    } catch (e) {
      error("背景分割失败: $e");
      state.dstImage = null;
    } finally {
      _endLoading();
    }
  }

  /// 转换标注框为比例坐标
  Rect _annotationBoxToImageRelativeRect() {
    final left = (state.annotationBoxRect.left - _imgRect.left) / _imgRect.width;
    final top = (state.annotationBoxRect.top - _imgRect.top) / _imgRect.height;
    final width = state.annotationBoxRect.width / _imgRect.width;
    final height = state.annotationBoxRect.height / _imgRect.height;
    debug("left: $left, top: $top, width: $width, height: $height");
    return Rect.fromLTWH(left, top, width, height);
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

  /// 数据重置
  void reset({bool notResetOperation = false}) {
    state.reset(notResetOperation: notResetOperation);
    resetSelf();
    update();
  }

  void resetSelf() {
    _imgRect = Rect.zero;
    _isDrawing = false;
  }

  /// 下载结果
  void saveResult() async {
    if (state.dstImage == null) {
      return;
    }
    final file = File(state.dstImage!.originalPath);
    final bytes = await file.readAsBytes();
    FilePicker.platform.saveFile(
      dialogTitle: "保存图像",
      type: FileType.image,
      bytes: bytes,
    );
    info("保存图像成功");
  }

  /// 复制结果至剪贴板
  void copyResult() async {
    final file = File(state.dstImage!.originalPath);
    final bytes = await file.readAsBytes();
    Pasteboard.writeImage(bytes);
    info("复制图像成功");
  }
}

enum ImgToolEnum {
  backgroundSplit("背景去除"),
  ;

  const ImgToolEnum(this.desc);

  final String desc;
}

enum _OperationEnum {
  left,
  right,
  top,
  bottom,
  none,
}
