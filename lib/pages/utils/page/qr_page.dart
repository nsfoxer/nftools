import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:nftools/common/style.dart';
import 'package:nftools/pages/utils/controller/qr_controller.dart';
import 'package:nftools/utils/log.dart';
import 'package:nftools/utils/nf_widgets.dart';

import '../../../src/bindings/bindings.dart';

class QrPage extends StatelessWidget {
  const QrPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ScaffoldPage.withPadding(
      header: PageHeader(
          title: const Text("二维码工具"),
          commandBar: GetBuilder<QrController>(
              builder: (logic) => CommandBar(
                    mainAxisAlignment: MainAxisAlignment.end,
                    primaryItems: [
                      CommandBarButton(
                          icon: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(FluentIcons.plain_text),
                              NFLayout.hlineh2,
                              Icon(logic.state.isData2Qr
                                  ? FluentIcons.double_chevron_right8
                                  : FluentIcons.double_chevron_left8),
                              NFLayout.hlineh2,
                              const Icon(FluentIcons.q_r_code)
                            ],
                          ),
                          label:
                              Text(logic.state.isData2Qr ? "二维码生成" : "二维码识别"),
                          onPressed: () {
                            logic.switchType();
                          }),
                      CommandBarButton(
                          icon: const Icon(FluentIcons.reset),
                          label: const Text("重置"),
                          onPressed: () => logic.reset()),
                    ],
                  ))),
      content: GetBuilder<QrController>(
          builder: (logic) => Row(
                children: [
                  Expanded(
                      flex: 1,
                      child: NFLoadingWidgets(
                          loading:
                              !logic.state.isData2Qr && logic.state.isLoading,
                          hint: "识别中",
                          child: Column(
                            children: [
                              Expanded(
                                flex: 1,
                                child: NFCodeEditor(
                                    wordWrap: true,
                                    readOnly: !logic.state.isData2Qr,
                                    hint: logic.state.isData2Qr
                                        ? "请输入要转换的文本"
                                        : "暂未解析出文本",
                                    controller:
                                        logic.state.codeLineEditingController),
                              ),
                              Expanded(
                                  flex: 1,
                                  child: NFCardContent(
                                      child: GestureDetector(
                                    onTap: () => logic.handleFile(),
                                    child: MouseRegion(
                                      cursor: SystemMouseCursors.click,
                                      child: Center(child: () {
                                        final path =
                                            logic.state.filePath != null
                                                ? "\n(${logic.state.filePath})"
                                                : "";
                                        if (logic.state.isData2Qr) {
                                          return Text("选取要转换的文件$path",
                                              textAlign: TextAlign.center);
                                        }
                                        if (logic.state.fileData.isEmpty) {
                                          return const Text("暂未解析出数据");
                                        }
                                        return Text("点击保存解析出的数据$path",
                                            textAlign: TextAlign.center);
                                      }()),
                                    ),
                                  )))
                            ],
                          ))),
                  IconButton(
                      icon: logic.state.isData2Qr
                          ? const Icon(FluentIcons.double_chevron_right8)
                          : const Icon(FluentIcons.double_chevron_left8),
                      onPressed: () => logic.switchType()),
                  NFLayout.hlineh2,
                  Expanded(
                      flex: 1,
                      child: () {
                        // 是展示图片结果
                        if (logic.state.isData2Qr) {
                          final provider = MemoryImage(logic.state.imageData);
                          return NFLoadingWidgets(
                              loading: logic.state.isLoading,
                              child: Center(
                                  child: logic.state.imageData.isEmpty
                                      ? const Text("二维码")
                                      : Image(
                                          image: provider,
                                          loadingBuilder:
                                              (ctx, child, loadingProgress) {
                                            if (loadingProgress == null) {
                                              // 图片加载完成后清除缓存
                                              provider.evict().then((success) {
                                                if (success) debug('图片已从缓存中移除');
                                              });
                                            }
                                            return child;
                                          },
                                        )));
                        }
                        // 图片识别
                        Widget display = const Text("选择图片或ctrl+v粘贴");
                        if (logic.state.imageDataForDecode.isNotEmpty) {
                          display = LayoutBuilder(builder:
                              (BuildContext context,
                                  BoxConstraints constraints) {
                            List<Positioned> list = _buildQrCodeData(
                                logic.state.qRData,
                                constraints.maxWidth,
                                constraints.maxHeight,
                                context,
                                logic);
                            final provider = MemoryImage(logic.state.imageDataForDecode);
                            return Stack(children: [
                              Container(
                                  color: Colors.blue,
                                  child: Image(
                                      fit: BoxFit.contain,
                                      image: provider,
                                      loadingBuilder:
                                          (ctx, child, loadingProgress) {
                                        if (loadingProgress == null) {
                                          // 图片加载完成后清除缓存
                                         provider.evict().then((success) {
                                            if (success) debug('图片已从缓存中移除');
                                          });
                                        }
                                        return child;
                                      })),
                              ...list,
                            ]);
                          });
                        }
                        return NFCardContent(
                            child: Shortcuts(
                                shortcuts: {
                              LogicalKeySet(LogicalKeyboardKey.control,
                                  LogicalKeyboardKey.keyV): _SubmitIntent(logic)
                            },
                                child: Actions(
                                    actions: {
                                      _SubmitIntent:
                                          CallbackAction<_SubmitIntent>(
                                              onInvoke: (_SubmitIntent intent) {
                                        intent.logic.decodePasteboardImage();
                                        return null;
                                      })
                                    },
                                    child: GestureDetector(
                                        onTap: () async {
                                          logic.readImage();
                                        },
                                        child: Focus(
                                          focusNode: logic.state.imageFocus,
                                          autofocus: true,
                                          child: MouseRegion(
                                            onEnter: (event) {
                                              logic.state.imageFocus
                                                  .requestFocus();
                                            },
                                            cursor: SystemMouseCursors.click,
                                            child: Center(
                                              child: display,
                                            ),
                                          ),
                                        )))));
                      }()),
                ],
              )),
    );
  }

  List<Positioned> _buildQrCodeData(
      QrCodeDataMsgList? qrCodeData,
      double maxWidth,
      double maxHeight,
      BuildContext context,
      QrController logic) {
    // 1. 为空时直接返回
    if (qrCodeData == null || qrCodeData.value.isEmpty) {
      return [];
    }

    // 2.需要画出每个二维码位置
    //  计算缩放比例
    final double ratio;
    if (maxWidth > qrCodeData.imageWidth &&
        maxHeight > qrCodeData.imageHeight) {
      ratio = 1;
    } else {
      final wRatio = maxWidth / qrCodeData.imageWidth;
      final hRatio = maxHeight / qrCodeData.imageHeight;
      ratio = wRatio < hRatio ? wRatio : hRatio;
    }

    // 3. 构建
    final color =
        FluentTheme.of(context).accentColor.normal.withValues(alpha: 0.7);
    final typography = FluentTheme.of(context).typography;
    return qrCodeData.value.map((e) {
      final height = (e.bl.item2 - e.tl.item2) * ratio;
      final width = (e.tr.item1 - e.tl.item1) * ratio;
      return Positioned(
        left: (e.tl.item1 + e.tr.item1) / 2 * ratio - (height / 2),
        top: (e.tl.item2 + e.bl.item2) / 2 * ratio - (width / 2),
        width: width,
        height: height,
        child: Container(
          color: color,
          child: Center(
            child: Tooltip(
              message: "识别",
              child: IconButton(
                  icon: Icon(
                    FluentIcons.q_r_code,
                    size: typography.bodyLarge?.fontSize,
                  ),
                  onPressed: () {
                    logic.handleQr(e);
                  }),
            ),
          ),
        ),
      );
    }).toList();
  }
}

// 快捷键intent
class _SubmitIntent extends Intent {
  final QrController logic;

  const _SubmitIntent(this.logic);
}
