import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:keymap/keymap.dart';
import 'package:nftools/utils/nf_widgets.dart';

import '../../../common/style.dart';
import '../controller/image_split_controller.dart';

class ImageSplitPage extends StatelessWidget {
  const ImageSplitPage({super.key});

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
                : Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                        CommandBar(primaryItems: [
                          // 操作
                          CommandBarButton(
                            label: Text("颜色"),
                            onPressed: () {},
                          ),
                          CommandBarButton(
                            label: Text("save"),
                            onPressed: () {
                              logic.state.controller.saveCanvas(r"C:\Users\12618\Desktop\box.png");
                            },
                          ),
                        ]),
                        NFLayout.vlineh0,
                        Expanded(
                            child: NFLoadingWidgets(
                          loading: logic.state.isLoading,
                          child: NFImagePainterPage(
                              controller: logic.state.controller),
                        ))
                      ]),
          );
        }));
  }
}
