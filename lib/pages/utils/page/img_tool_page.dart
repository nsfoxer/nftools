import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:keymap/keymap.dart';
import 'package:nftools/common/constants.dart';
import 'package:nftools/utils/nf_widgets.dart';
import 'package:nftools/utils/utils.dart';

import '../../../common/style.dart';
import '../controller/img_tool_controller.dart';

class ImgToolPage extends StatelessWidget {
  const ImgToolPage({super.key});

  @override
  Widget build(BuildContext context) {
    final imgLogic = Get.find<ImgToolController>();
    return ScaffoldPage.withPadding(
      header: PageHeader(
        title: Text("图片工具"),
        commandBar: CommandBar(
          mainAxisAlignment: MainAxisAlignment.end,
          primaryItems: [
            CommandBarButton(
              icon: Icon(FluentIcons.waitlist_confirm),
              label: Text("转换"),
              onPressed: imgLogic.convert,
            ),
            CommandBarButton(
              icon: Icon(FluentIcons.clear),
              label: Text("重置"),
              onPressed: imgLogic.reset,
            ),
          ],
        ),
      ),
      content: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GetBuilder<ImgToolController>(builder: (logic) {
              return Wrap(
                  spacing: NFLayout.v2,
                  runSpacing: NFLayout.v2,
                  children: ImgToolEnum.values
                      .map((e) => _EditButton(textToolEnum: e, logic: logic))
                      .toList());
            }),
            NFLayout.vlineh0,
            Expanded(child: GetBuilder<ImgToolController>(builder: (logic) {
              return NFLoadingWidgets(
                  loading: logic.state.isLoading,
                  child: Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 3,
                          child: ImgOperateArea(),
                        ),
                        NFLayout.hlineh2,
                        IconButton(
                            icon: Icon(FluentIcons.double_chevron_right8),
                            onPressed: imgLogic.convert),
                        NFLayout.hlineh2,
                        Expanded(
                          flex: 2,
                          child: ImgDisplay(),
                        ),
                      ]));
            }))
          ]),
    );
  }
}

class _EditButton extends StatelessWidget {
  final ImgToolEnum textToolEnum;
  final ImgToolController logic;

  const _EditButton({required this.textToolEnum, required this.logic});

  @override
  Widget build(BuildContext context) {
    return Button(
      onPressed: logic.state.operationEnum != textToolEnum
          ? () => logic.operate(textToolEnum)
          : null,
      child: Text(textToolEnum.desc),
    );
  }
}

/// 图片操作区域
class ImgOperateArea extends StatelessWidget {
  const ImgOperateArea({super.key});

  @override
  Widget build(BuildContext context) {
    return NFCardContent(
        noMargin: true,
        child: GetBuilder<ImgToolController>(builder: (logic) {
          return KeyboardWidget(
              bindings: [
                KeyAction(LogicalKeyboardKey.keyV, "粘贴图像", () {
                  logic.setPasteImg();
                }, isControlPressed: true),
              ],
              child: GestureDetector(
                onPanStart: logic.handlePanStart,
                onPanUpdate: logic.handlePanUpdate,
                onPanEnd: logic.handlePanEnd,
                onTapUp: logic.setFileImg,
                child: MouseRegion(
                    cursor: logic.getCursor(),
                    child: Center(
                      child: LayoutBuilder(
                        builder:
                            (BuildContext context, BoxConstraints constraints) {
                          if (logic.state.srcImage == null) {
                            return Text("选择图片或ctrl+v粘贴");
                          }
                          logic.resetImageRect(
                            constraints.maxWidth,
                            constraints.maxHeight,
                            logic.state.srcImage!.displayImgInfo.image.width
                                .toDouble(),
                            logic.state.srcImage!.displayImgInfo.image.height
                                .toDouble(),
                          );
                          return Stack(
                            children: [
                              Image(
                                image: logic.state.srcImage!.displayImg,
                                fit: BoxFit.contain,
                                width: constraints.maxWidth,
                                height: constraints.maxHeight,
                              ),
                              GetBuilder<ImgToolController>(
                                builder: (logic) {
                                  return _buildImgRect(logic, context);
                                },
                                id: PageWidgetNameConstant.drawRect,
                              ),
                            ],
                          );
                        },
                      ),
                    )),
              ));
        }));
  }

  /// 构建矩形
  /// @param logic 控制器
  /// @param context 上下文
  /// 仅当为背景分割时显示
  Widget _buildImgRect(ImgToolController logic, BuildContext context) {
    if (logic.state.operationEnum != ImgToolEnum.backgroundSplit) {
      return Container();
    }
    final pColor = primaryColor(context);
    final rect = logic.annotationBoxToScreenRect();
    if (rect.isEmpty) {
      return Container();
    }
    return Positioned(
      left: rect.left,
      top: rect.top,
      width: rect.width,
      height: rect.height,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: pColor,
            width: 1.5,
          ),
        ),
      ),
    );
  }
}

class ImgDisplay extends StatelessWidget {
  const ImgDisplay({super.key});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<ImgToolController>(builder: (logic) {
      if (logic.state.dstImage == null) {
        return Center(child: Text("输出图片"));
      }
      return Column(mainAxisAlignment: MainAxisAlignment.start, children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Tooltip(
              message: "保存图片",
              child: IconButton(
                  icon: Icon(FluentIcons.save),
                  onPressed: logic.saveResult),
            ),
            NFLayout.hlineh3,
            Tooltip(
              message: "复制图片",
              child: IconButton(
                  icon: Icon(FluentIcons.copy),
                  onPressed: logic.copyResult),
            )
          ],
        ),
        Expanded(
            child: Center(
                child: Container(
                    decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: primaryColor(context).withValues(alpha: 0.5),
                            spreadRadius: 5,
                            blurRadius: 20,
                          ),
                        ]),
                    child: Image(
                      image: logic.state.dstImage!.displayImg,
                      fit: BoxFit.contain,
                    )))),
      ]);
    });
  }
}
