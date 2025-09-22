import 'dart:math';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:get/get.dart';
import 'package:list_ext/list_ext.dart';
import 'package:path/path.dart' as path;
import 'package:go_router/go_router.dart';
import 'package:nftools/common/style.dart';
import 'package:nftools/pages/tar_pdf/controller/tar_pdf_controller.dart';
import 'package:nftools/pages/tar_pdf/state/tar_pdf_state.dart';
import 'package:nftools/src/bindings/bindings.dart';
import 'package:nftools/utils/nf_widgets.dart';
import 'package:tuple/tuple.dart';

import '../../../utils/log.dart';
import '../../../utils/utils.dart';

class TarPdfPage extends StatelessWidget {
  const TarPdfPage({super.key});

  @override
  Widget build(BuildContext context) {
    final typography = FluentTheme.of(context).typography;
    return ScaffoldPage.withPadding(
      header: PageHeader(
        title: Text('PDF归档'),
        commandBar: GetBuilder<TarPdfController>(
            builder: (logic) => CommandBar(
                  mainAxisAlignment: MainAxisAlignment.end,
                  primaryItems: [
                    CommandBarButton(
                      icon: const Icon(FluentIcons.settings),
                      label: const Text('配置'),
                      onPressed: () => _showSetting(context),
                    ),
                    CommandBarButton(
                        icon: const Icon(FluentIcons.next),
                        label: Text(
                            logic.state.processEnum == DisplayProcessEnum.order5
                                ? '导出结果'
                                : '下一步'),
                        onPressed: () {
                          logic.next();
                        }),
                    CommandBarButton(
                      icon: const Icon(FluentIcons.reset),
                      label: const Text('重置'),
                      onPressed: logic.reset,
                    ),
                  ],
                )),
      ),
      content: GetBuilder<TarPdfController>(builder: (logic) {
        List<BreadcrumbItem> breadItems = [];
        for (final process in DisplayProcessEnum.values) {
          breadItems.add(BreadcrumbItem(
            label: Text(process.desc, style: typography.bodyStrong),
            value: process.value,
          ));
          if (process == logic.state.processEnum) {
            break;
          }
        }
        return Column(
          spacing: NFLayout.v0,
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            BreadcrumbBar(items: breadItems),
            Expanded(
              child: _buildContent(logic, context),
            ),
          ],
        );
      }),
    );
  }

  Widget _buildContent(TarPdfController logic, BuildContext context) {
    switch (logic.state.processEnum) {
      case DisplayProcessEnum.order1:
        return _buildOrder1(logic);
      case DisplayProcessEnum.order2:
        return _buildOrder2(logic, context);
      case DisplayProcessEnum.order3:
        return _buildOrder3(logic, context);
      case DisplayProcessEnum.order4:
        return _buildOrder4(logic, context);
      case DisplayProcessEnum.order5:
        return _buildOrder5(logic, context);
      case DisplayProcessEnum.order6:
        return _buildOrder6(logic, context);
    }
  }

  Widget _buildOrder1(TarPdfController logic) {
    return NFLoadingWidgets(
        loading: logic.state.isLoading,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(flex: 1, child: Container()),
            Expanded(
                flex: 3,
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: NFLayout.v0,
                    children: [
                      InfoLabel(
                        label: "请选择pdf存储路径",
                        child: TextBox(
                          maxLines: 5,
                          placeholder: "请选择pdf存储路径",
                          readOnly: true,
                          onTap: logic.selectPdfDir,
                          controller: logic.state.pdfDirTextController,
                        ),
                      ),
                    ])),
            Expanded(flex: 1, child: Container()),
          ],
        ));
  }

  Widget _buildOrder2(TarPdfController logic, BuildContext context) {
    final typography = FluentTheme.of(context).typography;
    return NFTable(
        minWidth: 750,
        empty: Center(child: Text("empty")),
        header: [
          NFHeader(flex: 8, child: Text("文件名称", style: typography.bodyStrong)),
          NFHeader(flex: 2, child: Text("操作", style: typography.bodyStrong)),
        ],
        source: _Order2DataSource(logic.state.pdfFiles, logic, context));
  }

  Widget _buildOrder3(TarPdfController logic, BuildContext context) {
    final typography = FluentTheme.of(context).typography;
    List<Widget> textRects = logic.state.refOcrDatas
        .map((x) => _TextContainer(x.id, x.text, x.location, (id) {
              logic.selectTag(id, !logic.state.selectedTags.contains(id));
            }))
        .toList();
    return Row(
      children: [
        Expanded(
            flex: 8,
            child: NFLoadingWidgets(
                loading: logic.state.isLoading,
                child: InteractiveViewer(
                    child: Stack(
                  children: [
                    Stack(children: [
                      NFImagePainterPage(
                          controller: logic.state.refImagePainterController),
                      ...textRects,
                    ])
                  ],
                )))),
        Divider(direction: Axis.vertical),
        Expanded(
            flex: 3,
            child: NFLoadingWidgets(loading: logic.state.isRefOcrLoading, hint: "文字识别中...", child: Column(
              children: [
                Expanded(
                  flex: 1,
                  child: ListView.builder(
                    itemCount: logic.state.refOcrDatas.length + 1,
                    itemBuilder: (ctx, index) {
                      if (index == 0) {
                        return _Order3DataDisplay(
                            id: "标识",
                            text: "文本",
                            isTitle: true,
                            isSelected: false,
                            onSelectionChange: null);
                      }
                      final data = logic.state.refOcrDatas[index - 1];
                      return _Order3DataDisplay(
                        id: data.id,
                        text: data.text,
                        isTitle: false,
                        isSelected: logic.state.selectedTags
                            .contains(data.id),
                        onSelectionChange: (isSelected) {
                          logic.selectTag(data.id, isSelected);
                        },
                      );
                    },
                  ),
                ),
                Divider(),
                Expanded(
                    flex: 1,
                    child: SizedBox(
                        width: double.infinity,
                        child: Padding(
                            padding: EdgeInsetsGeometry.all(NFLayout.v3),
                            child: SingleChildScrollView(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Center(
                                      child: Text("已选中标识",
                                          style: typography.bodyStrong)),
                                  Wrap(
                                    spacing: NFLayout.v3,
                                    runSpacing: NFLayout.v3,
                                    children: logic.state.selectedTags
                                        .map((tag) => NFCardContent(
                                              noMargin: true,
                                              child: Text(tag),
                                            ))
                                        .toList(),
                                  )
                                ],
                              ),
                            )))),
                Divider(),
                Expanded(
                  flex: 1,
                  child: Padding(
                      padding: EdgeInsetsGeometry.all(NFLayout.v3),
                      child: Column(
                        mainAxisSize: MainAxisSize.max,
                        spacing: NFLayout.v3,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                              flex: 2,
                              child: InfoLabel(
                                  label: "请输入命名表达式:",
                                  child: TextBox(
                                      controller:
                                          logic.state.refTemplateController,
                                    onChanged: (value) {
                                      logic.tryGetRefTemplateResult();
                                    },
                                  ))),
                          Expanded(
                            flex: 3,
                            child: Column(
                              spacing: NFLayout.v4,
                              children: [
                                Text("表达式执行结果:", style: typography.caption),
                                Text(logic.state.refTemplateResultValue,
                                    style: typography.caption)
                              ],
                            ),
                          ),
                        ],
                      )),
                ),
              ],
            ))),
        Divider(direction: Axis.vertical),
      ],
    );
  }

  Widget _buildOrder4(TarPdfController logic, context) {
    return Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
      Expanded(flex: 2, child: Container()),
      Expanded(
          flex: 4,
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.center,
              spacing: NFLayout.v0,
              children: [
                Text(
                  "处理中......   ${logic.state.current}/${logic.state.sum}",
                ),
                SizedBox(
                    width: double.infinity,
                    child: ProgressBar(
                        backgroundColor:
                            isDark(context) ? NFColor.inactiveBackground : null,
                        value: logic.state.sum == 0
                            ? 0
                            : logic.state.current / logic.state.sum * 100)),
              ])),
      Expanded(
        flex: 2,
        child: Container(),
      ),
    ]);
  }

  Widget _buildOrder5(TarPdfController logic, BuildContext context) {
    if (logic.state.ocrResults == null) {
      return Center(
        child: Text("无结果!!!!!!!!!"),
      );
    }

    // 1. 计算成功数量
    final count = logic.state.ocrResults!.datas.length;
    final success = logic.state.ocrResults!.datas
        .where((element) => element.error.isEmpty
            && element.datas.values.firstWhereOrNull((x) => x.item2.isNotEmpty) == null)
        .length;
    final fail = count - success;
    final typography = FluentTheme.of(context).typography;

    List<NFHeader> headers = [
      NFHeader(flex: 2, child: Text("文件名", style: typography.bodyStrong)),
      NFHeader(flex: 2, child: Text("命名结果", style: typography.bodyStrong)),
    ];
    for (final item in logic.state.ocrResults!.tags) {
      headers.add(
        NFHeader(
          flex: 1,
          child: Text(item, style: typography.bodyStrong),
        ),
      );
    }
    headers.add(NFHeader(flex: 2, child: Text("错误信息", style: typography.bodyStrong)));

    return Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        spacing: NFLayout.v1,
        children: [
          Text(
            "处理已完成, 共发现$count个pdf文件,成功处理$success个,失败$fail个",
            style: typography.caption?.copyWith(
              decoration: TextDecoration.underline,
            ),
          ),
          Expanded(
            child: NFTable(
              isCompactMode: true,
              minWidth: 800,
              empty: Center(child: Text("无数据")),
              prototypeItem: NFRow(children: [
                Text(
                  "Some",
                  maxLines: 2, style: typography.caption,
                ),
              ]),
              header: headers,
              source: _DataSource(logic.state.ocrResults!.datas, logic, logic.state.ocrResults!.tags),
            ),
          ),
        ]);
  }

  void _showSetting(BuildContext context) async {
    final typography = FluentTheme.of(context).typography;
    var color = primaryColor(context);
    await showDialog<String>(
        context: context,
        builder: (context) => GetBuilder<TarPdfController>(builder: (logic) {
              return NFLoadingWidgets(
                  loading: logic.state.isConfigLoading,
                  child: ContentDialog(
                    title: Text("网络配置", style: typography.subtitle),
                    content: SingleChildScrollView(
                        child: Form(
                      key: logic.state.formKey,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        spacing: NFLayout.v0,
                        children: [
                          InfoLabel(
                              label: "服务器地址",
                              child: TextFormBox(
                                controller: logic.state.urlTextController,
                                cursorColor: color,
                                keyboardType: TextInputType.text,
                                placeholder: "https://xxx.xxxx.com/xxx/",
                                enableSuggestions: false,
                                validator: (v) {
                                  if (v!.startsWith("http://") ||
                                      v.startsWith("https://")) {
                                    return null;
                                  }
                                  return "必须以http://或https://开头";
                                },
                              )),
                          InfoLabel(
                              label: "密钥",
                              child: PasswordFormBox(
                                controller: logic.state.apiKeyTextController,
                                cursorColor: color,
                                placeholder: "XXXXXXXXXXXXXXXXXXX",
                                validator: (v) {
                                  if (v == '') {
                                    return "数据不能为空";
                                  }
                                  return null;
                                },
                              )),
                          InfoLabel(
                            label: "pdf密码",
                            child: PasswordFormBox(
                              controller: logic.state.pdfPasswordTextController,
                              cursorColor: color,
                              placeholder: "请输入pdf密码(没有则不填)",
                            ),
                          ),
                        ],
                      ),
                    )),
                    actions: [
                      FilledButton(
                          onPressed: () async {
                            if (!logic.state.formKey.currentState!.validate()) {
                              return;
                            }
                            if (await logic.setConfig() && context.mounted) {
                              context.pop();
                            }
                          },
                          child: const Text("提交")),
                      Button(
                          child: const Text("取消"),
                          onPressed: () {
                            logic.configReset();
                            context.pop();
                          })
                    ],
                  ));
            }));
  }

  Widget _buildOrder6(TarPdfController logic, BuildContext context) {
    final typography = FluentTheme.of(context).typography;
    return NFLoadingWidgets(loading: logic.state.isLoading, child: Column(
      children: [
        InfoLabel(
          label: "请选择重命名xlsx文件",
          child: TextBox(
            maxLines: 5,
            placeholder: "请选择重命名xlsx文件",
            readOnly: true,
            onTap: logic.selectExcelFile,
            controller: logic.state.renameFileController,
          ),
        ),
        if (logic.state.renameFileResult != null)
          Expanded(child:  NFTable(minWidth: 800,
              empty: Text("全部成功"),
              header: [
            NFHeader(flex: 1, child: Text("原始文件", style: typography.bodyStrong)),
            NFHeader(flex: 1, child: Text("失败原因", style: typography.bodyStrong)),
          ], source: _Order6DataSource(logic.state.renameFileResult!.value)))
      ],
    ));
  }
}

class _DataSource extends NFDataTableSource {
  final List<TarPdfResultMsg> data;
  final TarPdfController logic;
  final List<String> tags;

  _DataSource(this.data, this.logic, this.tags);

  @override
  NFRow getRow(BuildContext context, int index) {
    final caption = FluentTheme.of(context).typography.caption;
    final item = data[index];
    List<Widget> children = [];
    children.add(Tooltip(
        message: item.fileName,
        child: Text(
          item.fileName,
          style: caption,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        )));
    children.add(Tooltip(
        message: item.templateResult,
        child: Text(item.templateResult,
            style: caption, maxLines: 2, overflow: TextOverflow.ellipsis)));
    for (final tag in tags) {
      final data = item.datas[tag];
      if (data == null) {
        children.add(Text("-", overflow: TextOverflow.ellipsis, style: caption?.copyWith(color: Colors.grey)));
      } else {
        if (data.item2.isNotEmpty) {
          children.add(Tooltip(
              message: data.item2,
              child: Text(data.item2,  overflow: TextOverflow.ellipsis,
                  style: caption?.copyWith(color: Colors.red))));
        } else {
          children.add(Tooltip(
              message: data.item1,
              child: Text(
                data.item1,
                overflow: TextOverflow.ellipsis,
                style: caption,
                maxLines: 2,
              )));
        }
      }
    }
    children.add(Tooltip(
        message: item.error,
        child: Text(item.error,  overflow: TextOverflow.ellipsis, style: caption?.copyWith(color: Colors.red))));

    return NFRow(children: children);
  }

  @override
  bool get isEmpty => data.isEmpty;

  @override
  int? get itemCount => data.length;
}

class _Order2DataSource extends NFDataTableSource {
  final List<String> data;
  final TarPdfController logic;
  final BuildContext context;

  _Order2DataSource(this.data, this.logic, this.context) {
    _typography = FluentTheme.of(context).typography;
  }

  late Typography _typography;

  @override
  NFRow getRow(BuildContext context, int index) {
    final pdf = path.basename(data[index]);
    return NFRow(children: [
      Text(
        pdf,
        style: _typography.caption,
      ),
      Row(
          mainAxisAlignment: MainAxisAlignment.center,
          spacing: NFLayout.v2,
          children: [
            _PreviewButton(data[index], logic),
            FilledButton(
                child: Text("选中", style: _typography.caption),
                onPressed: () async {
                  final result =
                      await confirmDialog(context, "确认选中", "确认选择【$pdf】为参考吗?");
                  if (result) {
                    logic.order2SelectRef(data[index]);
                  }
                }),
          ]),
    ]);
  }

  @override
  bool get isEmpty => data.isEmpty;

  @override
  int? get itemCount => data.length;
}

// 预览按钮
class _PreviewButton extends StatelessWidget {
  final String pdfPath;
  final TarPdfController logic;

  final Rx<bool> _isLoading = false.obs;

  _PreviewButton(this.pdfPath, this.logic);

  @override
  Widget build(BuildContext context) {
    final typography = FluentTheme.of(context).typography;
    return Button(
        child: Obx(() => _isLoading.value
            ? SizedBox(
                height: 15, width: 15, child: ProgressRing(strokeWidth: 2))
            : Text("预览", style: typography.caption)),
        onPressed: () async {
          _isLoading.value = true;
          final timeResult =
              await measureFunctionTime(logic.order2Preview, [pdfPath]);
          debug("time: $timeResult");
          _isLoading.value = false;
          final img = timeResult.result;
          if (context.mounted) {
            _showPdfCover(context, img);
          } else {
            warn("context is not mounted");
          }
        });
  }

  static void _showPdfCover(
      BuildContext context, ImageProvider imageProvider) async {
    await showDialog(
      barrierDismissible: true,
      context: context,
      builder: (context) {
        return Column(
          spacing: NFLayout.v2,
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            InteractiveViewer(
                child: Image(
              image: imageProvider,
              fit: BoxFit.contain,
              width: MediaQuery.of(context).size.width * 0.9,
              height: MediaQuery.of(context).size.height * 0.8,
            )),
            IconButton(
              icon: const Icon(FluentIcons.chrome_close, size: 16),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
}

class _TextContainer extends StatelessWidget {
  final String id;
  final String text;
  final BoxPositionMsg position;
  final Function(String) onPress;

  const _TextContainer(this.id, this.text, this.position, this.onPress);

  @override
  Widget build(BuildContext context) {
    final theme = primaryColor(context);
    final background = WidgetStateProperty.resolveWith((states) {
      if (states.isEmpty) {
        return theme.withAlpha(150);
      }
      return theme.withAlpha(80);
    });
    return Positioned(
      left: position.x,
      top: position.y,
      width: position.width,
      height: position.height,
      child: Tooltip(
          message: "标识: $id\n$text",
          child: Button(
            style: ButtonStyle(backgroundColor: background),
            child: Container(),
            onPressed: () {
              onPress(id);
            },
          )),
    );
  }
}

class _Order3DataDisplay extends StatelessWidget {
  final String id;
  final String text;
  final bool isTitle;
  final bool isSelected;
  final Function(bool)? onSelectionChange;

  const _Order3DataDisplay(
      {super.key,
      required this.id,
      required this.text,
      required this.isTitle,
      required this.isSelected,
      required this.onSelectionChange});

  @override
  Widget build(BuildContext context) {
    final typography = FluentTheme.of(context).typography;
    return ListTile.selectable(
      title: Container(),
      subtitle: Row(
        children: [
          Expanded(
              flex: 1,
              child: Text(id,
                  style: isTitle ? typography.bodyStrong : typography.caption)),
          Expanded(
              flex: 5,
              child: Text(text,
                  style: isTitle ? typography.bodyStrong : typography.caption)),
        ],
      ),
      margin: EdgeInsets.all(0),
      contentPadding: EdgeInsets.all(0),
      onSelectionChange: isTitle ? null : onSelectionChange,
      selectionMode:
          isTitle ? ListTileSelectionMode.none : ListTileSelectionMode.multiple,
      selected: isSelected,
    );
  }
}

class _Order6DataSource extends NFDataTableSource {
  final List<Tuple2<String, String>> data;

  _Order6DataSource(this.data);

  @override
  NFRow getRow(BuildContext context, int index) {
    return NFRow(children: [
      Text(data[index].item1),
      Text(data[index].item2),
    ]);
  }

  @override
  bool get isEmpty => data.isEmpty;

  @override
  int? get itemCount => data.length;
}