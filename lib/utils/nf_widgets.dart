import 'dart:typed_data';
import 'dart:ui';
import 'dart:ui' as ui;

import 'package:fluent_ui/fluent_ui.dart';
import 'package:get/get.dart';
import 'package:list_ext/list_ext.dart';
import 'package:meta/meta.dart';
import 'package:nftools/common/style.dart';
import 'package:nftools/utils/utils.dart';
import 'package:re_editor/re_editor.dart';
import 'package:re_highlight/languages/dart.dart';
import 'package:re_highlight/languages/json.dart';
import 'package:re_highlight/languages/sql.dart';
import 'package:re_highlight/styles/base16/github.dart';
import 'package:re_highlight/styles/github-dark.dart';

// card 内容体
class NFCardContent extends StatelessWidget {
  const NFCardContent(
      {super.key, required this.child, this.noMargin, this.color});

  final Widget child;
  final bool? noMargin;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: (noMargin ?? false) ? null : const EdgeInsets.all(NFLayout.v2),
      padding: const EdgeInsets.all(NFLayout.v1),
      decoration: BoxDecoration(
          border:
              Border.all(color: FluentTheme.of(context).cardColor, width: 1),
          borderRadius: BorderRadius.circular(10.0),
          color: color ?? FluentTheme.of(context).cardColor),
      child: child,
    );
  }
}

class NFCard extends StatelessWidget {
  const NFCard({super.key, required this.title, required this.child});

  final Widget child;
  final String title;

  @override
  Widget build(BuildContext context) {
    Typography typography = FluentTheme.of(context).typography;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: typography.subtitle),
        NFLayout.vlineh2,
        NFCardContent(child: child),
        NFLayout.vlineh1,
      ],
    );
  }
}

// 加载组件
class NFLoadingWidgets extends StatelessWidget {
  final Widget child;
  final bool loading;
  final String hint;

  const NFLoadingWidgets({
    super.key,
    required this.loading,
    required this.child,
    this.hint = "加载中...",
  });

  @override
  Widget build(BuildContext context) {
    if (!loading) {
      return child;
    }
    return IgnorePointer(
        child: Stack(
      alignment: Alignment.center,
      children: [
        ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
          child: child,
        ),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [const ProgressRing(), NFLayout.vlineh1, Text(hint)],
        ),
      ],
    ));
  }
}

// 无尽旋转动画组件
class NFRotationWidget extends StatefulWidget {
  final Widget child;

  const NFRotationWidget({super.key, required this.child});

  @override
  State<StatefulWidget> createState() {
    return _NFRotationWidgetState();
  }
}

class _NFRotationWidgetState extends State<NFRotationWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(); // 循环动画
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _controller, // 使用 AnimationController 控制旋转
      child: widget.child,
    );
  }
}

class NFPanelWidget extends StatelessWidget {
  final Widget? leading;
  final Widget? trailing;

  const NFPanelWidget({super.key, this.leading, this.trailing});

  @override
  Widget build(BuildContext context) {
    List<Widget> children = [];
    children.add(Padding(
        padding: const EdgeInsets.symmetric(
            vertical: NFLayout.v2, horizontal: NFLayout.v1),
        child: leading ?? Container()));
    children.add(Padding(
        padding: const EdgeInsets.all(NFLayout.v3),
        child: trailing ?? Container()));
    return Container(
        padding: const EdgeInsets.all(NFLayout.v1),
        decoration: BoxDecoration(
            // border:
            //     Border.all(color: FluentTheme.of(context).cardColor, width: 1),
            borderRadius: BorderRadius.circular(6.0),
            color: FluentTheme.of(context).cardColor),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: children,
        ));
  }
}

// 代码编辑器
class NFCodeEditor extends StatelessWidget {
  final CodeLineEditingController controller;
  final bool? readOnly;
  final RxBool isDisplay = false.obs;
  final bool wordWrap;
  final String? hint;

  NFCodeEditor(
      {super.key,
      required this.controller,
      this.readOnly,
      this.wordWrap = false,
      this.hint});

  @override
  Widget build(BuildContext context) {
    final isDark = context.mediaQuery.platformBrightness.isDark;
    final typography = FluentTheme.of(context).typography;
    return NFCardContent(
        child: Stack(children: [
      CodeEditor(
        wordWrap: wordWrap,
        controller: controller,
        readOnly: readOnly ?? false,
        hint: hint,
        style: CodeEditorStyle(
          textColor: FluentTheme.of(context).typography.body?.color,
          codeTheme: CodeHighlightTheme(
            languages: {
              'json': CodeHighlightThemeMode(mode: langJson),
              'dart': CodeHighlightThemeMode(mode: langDart),
              'sql': CodeHighlightThemeMode(mode: langSql),
            },
            theme: isDark ? githubDarkTheme : githubTheme,
          ),
        ),
        indicatorBuilder:
            (context, editingController, chunkController, notifier) {
          return Row(
            children: [
              DefaultCodeLineNumber(
                controller: editingController,
                notifier: notifier,
                minNumberCount: 0,
              ),
              DefaultCodeChunkIndicator(
                  width: 5, controller: chunkController, notifier: notifier)
            ],
          );
        },
      ),
      Positioned(
          top: NFLayout.v4,
          right: NFLayout.v4,
          child: MouseRegion(
            onEnter: (event) {
              isDisplay.value = true;
            },
            onExit: (event) {
              isDisplay.value = false;
            },
            child: Obx(() => SizedBox(
                height: 30,
                width: 30,
                child: isDisplay.isFalse
                    ? Container()
                    : Tooltip(
                        message: "美化",
                        child: IconButton(
                            icon: Icon(FluentIcons.auto_enhance_on,
                                size: typography.caption?.fontSize),
                            onPressed: () {
                              bool success = true;
                              try {
                                final data = formatJson(controller.text);
                                controller.text = data;
                              } catch (ignored) {
                                // ignored
                                success = false;
                              }
                              if (!success) {
                                final data = formatSql(controller.text);
                                controller.text = data;
                              }
                            }),
                      ))),
          )),
    ]));
  }
}

// 高亮组件 start
class NFHighlight extends StatelessWidget {
  final Color? color;
  final bool isLight;
  final Widget child;

  const NFHighlight(
      {super.key, required this.isLight, this.color, required this.child});

  @override
  Widget build(BuildContext context) {
    List<BoxShadow>? boxShadow;
    final color = this.color ?? FluentTheme.of(context).accentColor.normal;
    if (isLight) {
      boxShadow = [
        BoxShadow(
            color: color.withValues(alpha: 0.2),
            spreadRadius: 0.1,
            blurRadius: 10)
      ];
    }
    return Container(
      padding: const EdgeInsets.all(NFLayout.v3),
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(1), boxShadow: boxShadow),
      child: child,
    );
  }
}
// 高亮组件 end

// 表格组件  start
class NFTable<T> extends StatefulWidget {
  final double minWidth;
  final List<NFHeader> header;
  final Widget? empty;
  final NFDataTableSource source;
  // 是否为紧凑模式
  final bool isCompactMode;

  // 构造原型
  final NFRow? prototypeItem;

  const NFTable(
      {super.key,
      required this.minWidth,
      required this.header,
      this.empty,
      required this.source,
      this.prototypeItem,
      this.isCompactMode = false});

  @override
  State<NFTable<T>> createState() => _NFTableState<T>();
}

class _NFTableState<T> extends State<NFTable<T>> {
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 空数据
    if (widget.source.isEmpty) {
      return Center(child: widget.empty ?? Container());
    }

    // 边框颜色 === divider的颜色
    final borderColor =
        (DividerTheme.of(context).decoration as BoxDecoration?)?.color ??
            Colors.teal;

    // 构建表格
    final table = ListView.builder(
        prototypeItem: widget.prototypeItem != null
            ? ListTile(
                margin: widget.isCompactMode ? EdgeInsets.zero : null,
                contentPadding: widget.isCompactMode ? EdgeInsets.zero : kDefaultListTilePadding,
                title: SizedBox(),
                subtitle: SizedBox(
                  height: widget.prototypeItem!.height,
                   child:  Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: widget.prototypeItem!.children,
                )),
                shape: Border(bottom: BorderSide(width: 1, color: borderColor)),
              )
            : null,
        itemCount: widget.source.itemCount == null
            ? null
            : widget.source.itemCount! + 1,
        itemBuilder: (context, index) {
          // 标题
          if (index == 0) {
            return ListTile(
                margin: widget.isCompactMode ? EdgeInsets.zero : null,
                contentPadding: widget.isCompactMode ? EdgeInsets.zero : kDefaultListTilePadding,
                title: SizedBox(),
                subtitle:
                 Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: widget.header
                      .map((e) =>
                          Expanded(flex: e.flex, child: Center(child: e.child)))
                      .toList(),
                ));
          }
          // 表数据
          index = index - 1;
          final row = widget.source.getRow(context, index);
          assert(
              row.children.length == widget.header.length, "row长度与header长度不一致");
          return ListTile.selectable(
            margin: widget.isCompactMode ? EdgeInsets.zero : null,
            contentPadding: widget.isCompactMode ? EdgeInsets.zero : kDefaultListTilePadding,
            title: Container(),
            subtitle: SizedBox(
              height: row.height,
              child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: row.children
                  .mapIndex((e, i) => Expanded(
                      flex: widget.header[i].flex,
                      child: Center(
                        child: Center(child: e),
                      )))
                  .toList(),
            )),
            shape: Border(bottom: BorderSide(width: 1, color: borderColor)),
            onSelectionChange: (v) {},
          );
        });

    // 添加水平滚动
    return LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
      if (constraints.maxWidth < widget.minWidth) {
        return Scrollbar(
            controller: _scrollController,
            child: SingleChildScrollView(
                controller: _scrollController,
                scrollDirection: Axis.horizontal,
                child: SizedBox(width: widget.minWidth, child: table)));
      }
      return table;
    });
  }
}

// 表格数据源
abstract class NFDataTableSource {
  // item长度
  int? get itemCount;

  // 是否为空
  bool get isEmpty;

  // 获取一行
  NFRow getRow(BuildContext context, int index);
}

@Immutable()
class NFHeader {
  final int flex;
  final Widget child;

  const NFHeader({required this.flex, required this.child});
}

@Immutable()
class NFRow {
  final double? height;
  final List<Widget> children;

  const NFRow({this.height, required this.children});
}
// 表格组件  end

/// 图片画画界面start
/// 图片绘制页面
class NFImagePainterPage extends StatelessWidget {
  const NFImagePainterPage({super.key, required this.controller, this.onRendered});

  final NFImagePainterController controller;
  // 新增：渲染完成回调
  final VoidCallback? onRendered;

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 当回调不为空时执行
      onRendered?.call();
    });
    final painter = _ImageMaskPainter(points: controller._points);
    controller._painter = painter;
    return GestureDetector(
      onPanUpdate: controller._handlePanUpdate,
      onPanStart: controller._handlePanStart,
      onPanEnd: controller._handlePanEnd,
      child:
          RepaintBoundary(child: LayoutBuilder(builder: (context, constraints) {
        return ValueListenableBuilder<Size>(
          valueListenable: controller._imgSize,
          builder: (ctx, size, child) {
            if (controller._imageProvider == null ||
                size.height == 0 ||
                size.width == 0) {
              controller._setDisplayRect(
                  Rect.fromPoints(Offset.zero,
                      Offset(constraints.maxWidth, constraints.maxHeight)),
                  Size(constraints.maxWidth, constraints.maxHeight));
              return CustomPaint(
                foregroundPainter: painter,
                child: Container(
                  color: Colors.grey,
                  width: constraints.maxWidth,
                  height: constraints.maxHeight,
                ),
              );
            }
            final displayRect = _calculateImageSize(
                Size(constraints.maxWidth, constraints.maxHeight), size);
            controller._setDisplayRect(
                displayRect, Size(constraints.maxWidth, constraints.maxHeight));
            return SizedBox(
              width: constraints.maxWidth,
              height: constraints.maxHeight,
              child: CustomPaint(
                foregroundPainter: painter,
                child: RepaintBoundary(
                    child: Image(
                        image: controller._imageProvider!,
                        fit: BoxFit.contain)),
              ),
            );
          },
        );
      })),
    );
  }

  Rect _calculateImageSize(Size constraints, Size imageSize) {
    // 计算图片显示的大小
    final maxScale = constraints.width / constraints.height;
    final imgScale = imageSize.width / imageSize.height;
    final double width, height;
    double dx = 0, dy = 0;
    if (maxScale > imgScale) {
      height = constraints.height;
      width = height * imgScale;
      dx = (constraints.width - width).abs() / 2;
    } else {
      width = constraints.width;
      height = width / imgScale;
      dy = (constraints.height - height).abs() / 2;
    }
    return Rect.fromLTWH(dx, dy, width, height);
  }
}

class _ImageMaskPainter extends CustomPainter {
  final ValueNotifier<List<_DrawData>> points;

  _ImageMaskPainter({required this.points}) : super(repaint: points);

  @override
  void paint(Canvas canvas, Size size) {
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
/// ```dart
///  // 创建控制器
///  final controller = ImagePainterController(DrawType.rect, 10, Colors.red, (type) {});
///
///  // 设置图片
///  controller.setImageProvider(Image.file(File(r""));
///
///  // 画矩形
///  controller.changeDrawType(DrawType.rect, 1, Colors.red);
///  // 画路径
///  controller.changeDrawType(DrawType.path, 1, Colors.green);
///  // 橡皮擦
///  controller.changeDrawType(DrawType.erase, 1, Colors.blue);
///  // 重置所有数据
///  controller.reset();
///
///  // 保存图片
///  controller.saveCanvas(r"tmp.png");
///
/// ```
class NFImagePainterController extends ChangeNotifier {
  /// 绘制点
  final ValueNotifier<List<_DrawData>> _points = ValueNotifier([]);

  /// 图片展示区域
  Rect _displayRect = Rect.zero;
  Rect get displayRect => _displayRect;

  /// 画板大小
  Size _boardSize = Size.zero;

  /// 绘制对象
  CustomPainter? _painter;

  /// 绘制结束回调
  Function(DrawType type) endType;

  /// 绘制开始回调
  Function(DrawType type) startType;

  /// 图片真实大小(非显示大小)
  final ValueNotifier<Size> _imgSize = ValueNotifier(Size.zero);
  Size get imgSize => _imgSize.value;

  /// 启用鼠标绘制
  bool enableMouse = false;

  ImageProvider? _imageProvider;

  void _setDisplayRect(Rect rect, Size boardSize) {
    _displayRect = rect;
    _boardSize = boardSize;
  }

  void reset() {
    _boardSize = Size.zero;
    _imageProvider = null;
    _displayRect = Rect.zero;
    _points.value.clear();
    _points.value.add(_DrawData(
      type: DrawType.none,
      width: 0,
      color: Colors.white,
      points: [],
    ));
    _points.notifyListeners();
  }

  NFImagePainterController(
      {type = DrawType.none,
      double width = 0.0,
      color = Colors.transparent,
      enableMouse = false,
      this.endType = _ignoreType,
      this.startType = _ignoreType}) {
    changeDrawType(type, width, color);
  }

  static void _ignoreType(DrawType type) {}

  Future<void> setImageProvider(ImageProvider imageProvider) async {
    _imageProvider = imageProvider;
    final info = await getImageInfoFromProvider(imageProvider);
    _imgSize.value =
        Size(info.image.width.toDouble(), info.image.height.toDouble());
    _imgSize.notifyListeners();
  }

  /// 更改绘制类型
  void changeDrawType(DrawType type, double width, Color color) {
    final newDrawInfo = _DrawData(
      type: type,
      width: width,
      color: color,
      points: [],
    );
    if (_points.value.isNotEmpty && _points.value.last.points.isEmpty) {
      _points.value.last = newDrawInfo;
    } else {
      _points.value.add(newDrawInfo);
    }
  }

  /// 清除数据
  void clearData() {
    final last = _points.value.last;
    _points.value.clear();
    _points.value.add(last.copyWith(points: []));
    _points.notifyListeners();
  }

  void _handlePanStart(DragStartDetails details) {
    if (!enableMouse) {
      return;
    }
    if (_points.value.last.type == DrawType.none ||
        !_displayRect.contains(details.localPosition)) {
      return;
    }
    startType(_points.value.last.type);
    _points.value.last.points.add(details.localPosition);
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    if (!enableMouse) {
      return;
    }
    if (_points.value.last.type == DrawType.none) {
      return;
    }
    final lastData = _points.value.last;
    if (!_displayRect.contains(details.localPosition)) {
      if (lastData.points.isNotEmpty) {
        _points.value.add(lastData.copyWith(
          points: [],
        ));
      }
      return;
    }

    lastData.points.add(details.localPosition);
    _points.notifyListeners();
  }

  void _handlePanEnd(DragEndDetails details) {
    if (!enableMouse) {
      return;
    }
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

  /// 限制类型数量
  /// @param type 类型
  /// @param num 数量
  void limitTypeNum(DrawType type, int num) {
    // 由于最后一个数据是绘制中数据，所以需要加1
    num += 1;
    List<_DrawData> newData = [];
    for (_DrawData data in _points.value) {
      if (data.type == type) {
        newData.add(data);
      }
    }

    if (newData.length > num) {
      newData = newData.sublist(newData.length - num, newData.length);
    }
    _points.value = newData;
    _points.notifyListeners();
  }

  /// 生成画画图像
  Future<(Size, Rect, Uint8List?)> saveCanvas() async {
    PictureRecorder recorder = PictureRecorder();
    Canvas canvas = Canvas(recorder);
    //获取图片大小
    // 通过 _painter 对象操作 canvas
    _painter!.paint(canvas, _boardSize);
    Picture picture = recorder.endRecording();
    ui.Image image = await picture.toImage(
        _boardSize.width.toInt(), _boardSize.height.toInt());
    // 获取字节，存入文件
    ByteData? byteData = await image.toByteData(format: ImageByteFormat.png);

    return (_boardSize, _displayRect, byteData?.buffer.asUint8List());
  }

  void redo() {
    if (_points.value.length <= 1) {
      return;
    }
    _points.value.removeLast();
    _points.value.last.points = [];
   _points.notifyListeners();
  }

  /// 在图片上直接绘制
  /// 此函数会直接计算偏移
  void drawRectOnImg(Rect rect) {
    changeDrawType(DrawType.rect, 3, Colors.red);
    _points.value.last.points.add(rect.topLeft + _displayRect.topLeft);
    _points.value.last.points.add(rect.bottomRight + _displayRect.topLeft);
    _points.notifyListeners();
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

  @override
  String toString() {
    return '_DrawData{type: $type, width: $width, color: $color, points: $points}';
  }
}

/// 图片绘制页面 end
