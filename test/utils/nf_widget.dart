import 'dart:io';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:nftools/utils/nf_widgets.dart';


/// NFImagePainter 测试页面
class TestPage extends StatelessWidget {
  final NFImagePainterController controller =
  NFImagePainterController();

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
              child: NFImagePainterPage(controller: controller),
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
                  controller.saveCanvas();
                })
          ],
        ),
      ],
    );
  }
}