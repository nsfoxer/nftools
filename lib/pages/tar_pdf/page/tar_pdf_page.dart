import 'package:fluent_ui/fluent_ui.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';
import 'package:nftools/common/style.dart';
import 'package:nftools/pages/tar_pdf/controller/tar_pdf_controller.dart';
import 'package:nftools/pages/tar_pdf/state/tar_pdf_state.dart';
import 'package:nftools/src/bindings/bindings.dart';
import 'package:nftools/utils/nf_widgets.dart';

import '../../../utils/log.dart';
import '../../../utils/utils.dart';

class TarPdfPage extends StatelessWidget {
  const TarPdfPage({super.key});

  @override
  Widget build(BuildContext context) {
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
                      label: const Text('开始处理'),
                      onPressed: () {
                        logic.start();
                      },
                    ),
                    CommandBarButton(
                      icon: const Icon(FluentIcons.reset),
                      label: const Text('重置'),
                      onPressed: logic.reset,
                    ),
                  ],
                )),
      ),
      content: GetBuilder<TarPdfController>(builder: (logic) {
        switch (logic.state.processEnum) {
          case DisplayProcessEnum.start:
            return _buildStart(logic);
          case DisplayProcessEnum.processing:
            return _buildProcessing(logic);
          case DisplayProcessEnum.end:
            return _buildEnd(logic, context);
        }
      }),
    );
  }

  Widget _buildStart(TarPdfController logic) {
    return Row(
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
                      maxLines: 1,
                      readOnly: true,
                      onTap: logic.selectPdfDir,
                      controller: logic.state.pdfDirTextController,
                    ),
                  ),
                ])),
        Expanded(flex: 1, child: Container()),
      ],
    );
  }

  Widget _buildProcessing(TarPdfController logic) {
    return Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
      Expanded(flex: 1, child: Container()),
      Expanded(
          flex: 3,
          child: Center(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.center,
                  spacing: NFLayout.v0,
                  children: [
                Text(
                  "processing...   ${logic.state.current}/${logic.state.sum}",
                ),
                ProgressBar(
                    value: logic.state.sum == 0
                        ? 0
                        : logic.state.current / logic.state.sum * 100),
              ]))),
      Expanded(
        flex: 1,
        child: Container(),
      ),
    ]);
  }

  Widget _buildEnd(TarPdfController logic, BuildContext context) {
    final count = logic.state.ocrResult.length;
    final success = logic.state.ocrResult
        .where((element) => element.errorMsg.isEmpty)
        .length;
    final fail = count - success;
    final typography = FluentTheme.of(context).typography;
    return Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
      Text("处理已完成, 共发现$count个pdf文件,成功处理$success个,失败$fail个"),
      Expanded(
        child: NFTable(
          minWidth: 400,
          empty: Center(child: Text("empty")),
          prototypeItem: NFRow(children: [
            Text(
              "Some",
              style: typography.bodyStrong,
            )
          ]),
          header: [
            NFHeader(
                flex: 1,
                child: Text(
                  "处理文件",
                  style: typography.bodyStrong,
                )),
            NFHeader(
                flex: 2,
                child: Text(
                  "识别结果",
                  style: typography.bodyStrong,
                )),
            NFHeader(
                flex: 2,
                child: Text(
                  "错误信息",
                  style: typography.bodyStrong,
                )),
          ],
          source: _DataSource(logic.state.ocrResult, logic),
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
              return ContentDialog(
                title: Text("网络配置", style: typography.subtitle),
                content: Scrollbar(
                    child: SingleChildScrollView(
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
                      InfoLabel(
                          label: "编号正则配置",
                          child: _MultiText(
                            controllers: logic.state.regexTextControllers,
                            onTapOutside: (i) {
                              debug("editing complete $i");
                              if (logic
                                  .state.regexTextControllers[i].text.isEmpty) {
                                logic.removeRegex(i);
                              } else {
                                logic.trySupplyNewText();
                              }
                            },
                            remove: (i) {
                              logic.removeRegex(i);
                            },
                          )),
                    ],
                  ),
                ))),
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
              );
            }));
  }
}

class _DataSource extends NFDataTableSource {
  final List<TarPdfResultMsg> data;
  final TarPdfController logic;

  _DataSource(this.data, this.logic);

  @override
  NFRow getRow(BuildContext context, int index) {
    final item = data[index];
    debug("msg: ${item.errorMsg}");
    return NFRow(children: [
      Text(
        item.fileName,
        maxLines: 2,
      ),
      Text(
        item.title,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      Text(
        item.errorMsg,
        maxLines: 2,
        style: TextStyle(color: Colors.red),
        overflow: TextOverflow.ellipsis,
      ),
    ]);
  }

  @override
  bool get isEmpty => data.isEmpty;

  @override
  int? get itemCount => data.length;
}

class _MultiText extends StatelessWidget {
  final List<TextEditingController> controllers;
  final void Function(int index) onTapOutside;
  final void Function(int index) remove;

  const _MultiText(
      {required this.controllers,
      required this.onTapOutside,
      required this.remove});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      spacing: NFLayout.v2,
      children: [
        for (var i = 0; i < controllers.length; i++)
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Flexible(
                  child: TextFormBox(
                controller: controllers[i],
                cursorColor: primaryColor(context),
                keyboardType: TextInputType.text,
                placeholder: "请输入[编号]正则表达式",
                enableSuggestions: false,
                onTapOutside: (p) => onTapOutside(i),
              )),
              if (i != controllers.length - 1)
                IconButton(
                    icon: Icon(FluentIcons.delete, color: Colors.red),
                    onPressed: () => remove(i)),
            ],
          ),
      ],
    );
  }
}
