import 'dart:io';
import 'dart:ui';
import 'dart:ui' as ui;

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/foundation.dart';

import '../../../utils/log.dart';
import '../../../utils/utils.dart';

class TestPage extends StatelessWidget {
  final ImagePainterController controller =
      ImagePainterController(DrawType.rect, 10, Colors.red, (type) {
    debug("endType: $type");
  });

  TestPage({super.key});

  @override
  Widget build(BuildContext context) {
    final imageProvider = Image.file(
      File(r"C:\Users\12618\Pictures\wallpaper\【哲风壁纸】CP-动物背影.png"),
      fit: BoxFit.contain,
    ).image;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Expanded(
            child: Container(
          color: Colors.white,
          child: ImagePainterPage(controller: controller),
        )),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Button(
                child: Text("set image"),
                onPressed: () {
                  controller.setImageProvider(imageProvider);
                }),
            Button(
                child: Text("rect"),
                onPressed: () {
                  controller.changeDrawType(DrawType.rect, 1, Colors.red);
                }),
            Button(
                child: Text("erase"),
                onPressed: () {
                  controller.changeDrawType(DrawType.erase, 1, Colors.blue);
                }),
            Button(
                child: Text("path"),
                onPressed: () {
                  controller.changeDrawType(DrawType.path, 1, Colors.green);
                }),
            Button(
              child: Text("reset"),
              onPressed: () {
                controller.reset();
              },
            ),
            Button(
                child: Text("save"),
                onPressed: () {
                  controller.saveCanvas(r"C:\Users\12618\Desktop\box.png");
                })
          ],
        ),
      ],
    );
  }
}

/// 图片绘制页面
class ImagePainterPage extends StatelessWidget {
  const ImagePainterPage({super.key, required this.controller});

  final ImagePainterController controller;

  @override
  Widget build(BuildContext context) {
    final painter = _ImageMaskPainter(points: controller._points);
    controller._painter = painter;
    return GestureDetector(
      onPanUpdate: controller._handlePanUpdate,
      onPanStart: controller._handlePanStart,
      onPanEnd: controller._handlePanEnd,
      onTapDown: (details) {
        debug("tapDown: ${details.localPosition}");
      },
      child:
          RepaintBoundary(child: LayoutBuilder(builder: (context, constraints) {
        return ValueListenableBuilder<Size>(
          valueListenable: controller._imgSize,
          builder: (ctx, size, child) {
            if (controller.imageProvider == null) {
              controller._setDisplayRect(Rect.fromPoints(Offset.zero,
                  Offset(constraints.maxWidth, constraints.maxHeight)));
              return CustomPaint(
                foregroundPainter: painter,
                child: Container(
                  color: Colors.grey,
                  width: constraints.maxWidth,
                  height: constraints.maxHeight,
                ),
              );
            }
            final displayRect = _caculateImageSize(
                Size(constraints.maxWidth, constraints.maxHeight), size);
            controller._setDisplayRect(displayRect);
            return SizedBox(
              width: displayRect.width,
              height: displayRect.height,
              child: CustomPaint(
                foregroundPainter: painter,
                child: RepaintBoundary(
                    child: Image(image: controller.imageProvider!)),
              ),
            );
          },
        );
      })),
    );
  }

  Rect _caculateImageSize(Size constraints, Size imageSize) {
    // 计算图片显示的大小
    final maxScale = constraints.width / constraints.height;
    final imgScale = imageSize.width / imageSize.height;
    final double width, height;
    double dx = 0, dy = 0;
    if (maxScale > imgScale) {
      height = constraints.width;
      width = height * imgScale;
      dx = (constraints.width - width) / 2;
    } else {
      width = constraints.width;
      height = width / imgScale;
      dy = (constraints.height - height) / 2;
    }
    return Rect.fromLTWH(dx, dy, width, height);
  }
}

class _ImageMaskPainter extends CustomPainter {
  final ValueNotifier<List<_DrawData>> points;

  _ImageMaskPainter({required this.points}) : super(repaint: points);

  @override
  void paint(Canvas canvas, Size size) {
    debug("paint $size");
    final rect = Offset.zero & size;
    // 保存画布
    canvas.saveLayer(rect, Paint());
    for (_DrawData data in points.value) {
      final paint = data.getPaint();
      switch (data.type) {
        case DrawType.rect:
          _drawRect(canvas, paint, data.points);
          break;
        case DrawType.path:
          _drawPath(canvas, paint, data.points);
          break;
        case DrawType.erase:
          // canvas.saveLayer(rect, Paint());
          _drawPath(canvas, paint, data.points);
          break;
        case DrawType.none:
          break;
      }
    }
    canvas.restore();
  }

  void _drawRect(Canvas canvas, Paint paint, List<Offset> points) {
    if (points.length < 2) {
      return;
    }
    final rect = Rect.fromPoints(points.first, points.last);
    canvas.drawRect(rect, paint);
  }

  void _drawPath(Canvas canvas, Paint paint, List<Offset> points) {
    if (points.isNotEmpty) {
      final path = Path();
      path.moveTo(points[0].dx, points[0].dy);
      for (int i = 0; i < points.length; i++) {
        path.lineTo(points[i].dx, points[i].dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}

/// 图片画笔控制器
class ImagePainterController {
  /// 绘制点
  final ValueNotifier<List<_DrawData>> _points = ValueNotifier([]);

  /// 绘制区域
  Rect _displayRect = Rect.zero;

  /// 绘制对象
  CustomPainter? _painter;

  /// 绘制结束回调
  Function(DrawType type) endType = (type) {};

  /// 图片实际大小
  final ValueNotifier<Size> _imgSize = ValueNotifier(Size.zero);

  ImageProvider? imageProvider;

  void _setDisplayRect(Rect rect) {
    _displayRect = rect;
  }

  void reset() {
    _points.value.clear();
    _points.value.add(_DrawData(
      type: DrawType.none,
      width: 0,
      color: Colors.white,
      points: [],
    ));
    _points.notifyListeners();
  }

  ImagePainterController(DrawType type, double width, Color color,
      Function(DrawType type)? endType) {
    changeDrawType(type, width, color);
    if (endType != null) {
      this.endType = endType;
    }
  }

  Future<void> setImageProvider(ImageProvider imageProvider) async {
    this.imageProvider = imageProvider;
    final info = await getImageInfoFromProvider(imageProvider);
    _imgSize.value =
        Size(info.image.width.toDouble(), info.image.height.toDouble());
    _imgSize.notifyListeners();
  }

  /// 更改绘制类型
  void changeDrawType(DrawType type, double width, Color color) {
    _points.value.add(_DrawData(
      type: type,
      width: width,
      color: color,
      points: [],
    ));
  }

  void _handlePanStart(DragStartDetails details) {
    if (_points.value.last.type == DrawType.none) {
      return;
    }
    // 获取绘制区域
    _points.value.last.points.add(details.localPosition);
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    if (_points.value.last.type == DrawType.none) {
      return;
    }
    final lastData = _points.value.last;
    if (!_displayRect.contains(details.localPosition)) {
      _points.value.add(lastData.copyWith(
        points: [],
      ));
      return;
    }

    lastData.points.add(details.localPosition);
    _points.notifyListeners();
  }

  void _handlePanEnd(DragEndDetails details) {
    if (_points.value.last.type == DrawType.none) {
      return;
    }
    _points.value.add(_DrawData(
      type: _points.value.last.type,
      width: _points.value.last.width,
      color: _points.value.last.color,
      points: [],
    ));
    endType(_points.value.last.type);
  }

  /// 生成画画图像
  Future<void> saveCanvas(String path) async {
    PictureRecorder recorder = PictureRecorder();
    Canvas canvas = Canvas(recorder);
    //获取图片大小
    // 通过 _painter 对象操作 canvas
    _painter!.paint(canvas, _displayRect.size);
    Picture picture = recorder.endRecording();
    ui.Image image = await picture.toImage(
        _displayRect.width.toInt(), _displayRect.height.toInt());
    // 获取字节，存入文件
    ByteData? byteData = await image.toByteData(format: ImageByteFormat.png);
    if (byteData != null) {
      File file = File(path);
      file.writeAsBytes(byteData.buffer.asUint8List());
    }
  }
}

/// 绘制类型
enum DrawType {
  /// 矩形
  rect,

  /// 路径
  path,

  /// 橡皮
  erase,

  /// nothing
  none
}

/// 绘制数据
class _DrawData {
  /// 绘制类型
  DrawType type;

  /// 绘制宽度
  double width;

  /// 绘制颜色
  Color color;

  /// 绘制点
  List<Offset> points;

  _DrawData({
    required this.type,
    required this.width,
    required this.color,
    required this.points,
  });

  _DrawData copyWith({required List<Offset> points}) {
    return _DrawData(
      type: type,
      width: width,
      color: color,
      points: points,
    );
  }

  Paint getPaint() {
    var paint = Paint()
      ..isAntiAlias = true
      ..color = color
      ..strokeCap = StrokeCap.round
      ..strokeWidth = width;
    switch (type) {
      case DrawType.rect:
        paint.style = PaintingStyle.stroke;
        break;
      case DrawType.path:
        paint.style = PaintingStyle.stroke;
        break;
      case DrawType.erase:
        paint.style = PaintingStyle.stroke;
        paint.color = Colors.transparent;
        paint.blendMode = BlendMode.clear;
        break;
      case DrawType.none:
        break;
    }
    return paint;
  }
}
