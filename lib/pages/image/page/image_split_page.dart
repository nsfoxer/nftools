import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:keymap/keymap.dart';
import 'package:nftools/utils/nf_widgets.dart';

import '../controller/image_split_controller.dart';

class ImageSplitPage extends StatelessWidget {
  const ImageSplitPage({super.key});

  void _showPainterWidthDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => ContentDialog(
        title: const Text("画笔宽度"),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          GetBuilder<ImageSplitController>(
              builder: (logic) => Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text("${logic.state.painterWidth.toInt()}"),
                      Slider(
                          min: 1,
                          max: 20,
                          value: logic.state.painterWidth,
                          onChanged: (v) {
                            logic.changePainterWidth(v.ceilToDouble());
                          }),
                    ],
                  ))
        ]),
      ),
      barrierDismissible: true,
      dismissWithEsc: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ScaffoldPage.withPadding(
        header: PageHeader(
            title: const Text("前景分割"),
            commandBar: GetBuilder<ImageSplitController>(
              builder: (logic) => CommandBar(
                  mainAxisAlignment: MainAxisAlignment.end,
                  primaryItems: [
                    CommandBarButton(
                        icon: Icon(FluentIcons.circle_fill,
                            size: logic.state.painterWidth),
                        label: Text("画笔宽度"),
                        onPressed: () {
                          _showPainterWidthDialog(context);
                        }),
                    CommandBarButton(
                      icon: Icon(FluentIcons.next),
                      label: Text("下一步"),
                      onPressed: () {},
                    ),
                    CommandBarButton(
                        icon: Icon(FluentIcons.clear),
                        label: Text("重置"),
                        onPressed: () {
                          logic.reset();
                        }),
                  ]),
            )),
        content: GetBuilder<ImageSplitController>(builder: (logic) {
          return KeyboardWidget(
            bindings: [
              KeyAction(LogicalKeyboardKey.keyV, "粘贴图像", () {},
                  isControlPressed: true),
            ],
            child: logic.state.originalImage == null
                ? GestureDetector(
                    onTapUp: (details) {
                      logic.setFileImg();
                    },
                    child: NFCardContent(
                        child: Center(child: Text("选择图片或ctrl+v粘贴"))),
                  )
                : NFLoadingWidgets(
                    loading: logic.state.isLoading,
                    child:
                        NFImagePainterPage(controller: logic.state.controller),
                  ),
          );
        }));
  }
}
