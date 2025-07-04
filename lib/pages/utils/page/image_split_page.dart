import 'dart:io';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:keymap/keymap.dart';
import 'package:nftools/common/style.dart';
import 'package:nftools/pages/utils/state/Image_split_state.dart';
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
      dismissWithEsc: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ScaffoldPage.withPadding(
        header: PageHeader(
            title: const Text("前景分割"),
            commandBar: GetBuilder<ImageSplitController>(
              builder: (logic) => CommandBar(
                  direction: Axis.horizontal,
                  mainAxisAlignment: MainAxisAlignment.end,
                  primaryItems: [
                    CommandBarButton(
                        icon: Icon(FluentIcons.redo),
                        label: Text("撤销"),
                        onPressed: logic.redo),
                    CommandBarButton(
                        icon: Icon(FluentIcons.add_in),
                        label:
                            Text(logic.state.isAddAreaMode ? "标记前景" : "标记背景"),
                        onPressed: logic.state.step == DrawStep.rect
                            ? null
                            : logic.changeAreaMode),
                    CommandBarButton(
                        icon: Icon(FluentIcons.circle_fill,
                            size: logic.state.painterWidth, color: logic.getColor()),
                        label: Text("宽度"),
                        onPressed: () {
                          _showPainterWidthDialog(context);
                        }),
                    CommandBarButton(
                      icon: Icon(FluentIcons.next),
                      label: Text("处理"),
                      onPressed: !logic.state.isPreview ? logic.next : null,
                    ),
                    CommandBarButton(
                        icon: Icon(FluentIcons.preview),
                        label: Text("预览"),
                        onPressed: logic.state.step == DrawStep.rect
                            ? null
                            : logic.preview),
                    CommandBarButton(
                        icon: Icon(FluentIcons.clear),
                        label: Text("重置"),
                        onPressed: logic.reset),
                  ]),
            )),
        content: GetBuilder<ImageSplitController>(builder: (logic) {
          return KeyboardWidget(
            bindings: [
              KeyAction(LogicalKeyboardKey.keyV, "粘贴图像", () {},
                  isControlPressed: true),
            ],
            child: logic.state.currentImage == null
                ? GestureDetector(
                    onTapUp: (details) {
                      logic.setFileImg();
                    },
                    child: NFCardContent(
                        child: Center(child: Text("选择图片或ctrl+v粘贴"))),
                  )
                : NFLoadingWidgets(
                    loading: logic.state.isLoading,
                    child: InteractiveViewer(
                        maxScale: 10,
                        child: logic.state.isPreview
                            ? Center(
                                child: Stack(
                                children: [
                                  if (logic.state.previewImage != null)
                                    Image.memory(logic.state.previewImage!),
                                  Positioned(
                                      right: NFLayout.v0,
                                      top: NFLayout.v0,
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.end,
                                        mainAxisSize: MainAxisSize.min,
                                        spacing: NFLayout.v1,
                                        children: [
                                          Tooltip(
                                            message: "复制",
                                            child: IconButton(
                                                icon: Icon(FluentIcons.copy),
                                                onPressed: logic.copyResult),
                                          ),
                                          Tooltip(
                                            message: "保存",
                                            child: IconButton(
                                                icon:
                                                    Icon(FluentIcons.download),
                                                onPressed: logic.saveResult),
                                          ),
                                        ],
                                      )),
                                ],
                              ))
                            : NFImagePainterPage(
                                controller: logic.state.controller)),
                  ),
          );
        }));
  }
}
