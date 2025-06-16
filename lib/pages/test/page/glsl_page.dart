
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_shaders/flutter_shaders.dart';

class GlslPage extends StatefulWidget {
  const GlslPage({super.key});

  @override
  State<GlslPage> createState() => _GlslPageState();
}

Future<ui.Image> loadImageFromProvider(ImageProvider provider) async {
  final ImageStream stream = provider.resolve(ImageConfiguration.empty);

  // 使用Completer等待图像加载完成
  final Completer<ui.Image> completer = Completer<ui.Image>();
  final ImageStreamListener listener = ImageStreamListener(
        (ImageInfo imageInfo, bool synchronousCall) {
      completer.complete(imageInfo.image);
    },
    onError: (dynamic exception, StackTrace? stackTrace) {
      completer.completeError(exception, stackTrace);
    },
  );

  stream.addListener(listener);

  try {
    return await completer.future;
  } finally {
    stream.removeListener(listener);
  }
}

class _GlslPageState extends State<GlslPage> {


  late Ticker _ticker;

  Duration _elapsed = Duration.zero;
  ui.Image? _image = null;

  @override
  void initState() {
    super.initState();
    _ticker = Ticker((elapsed) {
      setState(() {
        _elapsed = elapsed;
      });
    });
    // _ticker.start();

    _init();
  }
  
  void _init() async {
    _image = await loadImageFromProvider(FileImage(File(r"C:\Users\12618\Pictures\wallpaper\wallhaven-vq5rol_2560x1440.png")));
    setState(() {});
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_image == null) {
      return Container();
    }

    final body = ShaderBuilder(
        assetKey: 'assets/shaders/wrap.frag',
        (context, shader, child) {
          return CustomPaint(
            size: MediaQuery.of(context).size,
            painter: ShaderCustomPainter(shader, _image!),
          );
        }
    );

    return ScaffoldPage.withPadding(content: body);
  }

}

class ShaderCustomPainter extends CustomPainter {
  final FragmentShader shader;
  // final Duration currentTime;
  final ui.Image img;

  ShaderCustomPainter(this.shader, this.img);

  @override
  void paint(Canvas canvas, Size size) {
    shader.setFloat(0, size.width);
    shader.setFloat(1, size.height);
    // shader.setFloat(2, currentTime.inMilliseconds.toDouble() / 1000.0);
    shader.setImageSampler(0, img);
    final Paint paint = Paint()..shader = shader;
    canvas.drawRect(Offset.zero & size, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}