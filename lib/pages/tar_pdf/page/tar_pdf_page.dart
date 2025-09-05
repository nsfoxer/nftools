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
                      onPressed: (logic.state.pdfDirTextController.text.isEmpty || logic.state.processEnum != DisplayProcessEnum.start)
                          ? null
                          : () {
                              logic.start();
                            },
                    ),
                    CommandBarButton(
                      icon: const Icon(FluentIcons.excel_document),
                      label: const Text('导出结果'),
                      onPressed: logic.state.canExport
                          ? () {
                              logic.exportResult();
                            }
                          : null,
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
            return _buildProcessing(logic, context);
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
    );
  }

  Widget _buildProcessing(TarPdfController logic, context) {
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
                        backgroundColor: isDark(context) ? NFColor.inactiveBackground : null,
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

  Widget _buildEnd(TarPdfController logic, BuildContext context) {
    final count = logic.state.ocrResult.length;
    final success = logic.state.ocrResult
        .where((element) => element.errorMsg.isEmpty)
        .length;
    final fail = count - success;
    final typography = FluentTheme.of(context).typography;
    return Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        spacing: NFLayout.v1,
        children: [
      Text("处理已完成, 共发现$count个pdf文件,成功处理$success个,失败$fail个", style: typography.caption?.copyWith(
        decoration: TextDecoration.underline,
      ),),
      Expanded(
        child: NFTable(
          minWidth: 800,
          empty: Center(child: Text("empty")),
          prototypeItem: NFRow(children: [
            Text(
              "Some",
              maxLines: 2,
            )
          ]),
          header: [
            NFHeader(
                flex: 1,
                child: Tooltip(
                    message: "序号(index)",
                    child: Text(
                      "序号",
                      maxLines: 1,
                      style: typography.bodyStrong,
                    ))),
            NFHeader(
                flex: 2,
                child: Tooltip(
                    message: "原始文件名(file_name)",
                    child: Text(
                      "原始文件",
                      maxLines: 1,
                      style: typography.bodyStrong,
                    ))),
            NFHeader(
                flex: 3,
                child: Tooltip(
                    message: "项目标题(title)",
                    child: Text(
                      "项目标题",
                      maxLines: 1,
                      style: typography.bodyStrong,
                    ))),
            NFHeader(
                flex: 3,
                child: Tooltip(
                    message: "项目编号(no)",
                    child: Text(
                      "项目编号",
                      maxLines: 1,
                      style: typography.bodyStrong,
                    ))),
            NFHeader(
                flex: 3,
                child: Tooltip(
                    message: "企业名称(company_name)",
                    child: Text(
                      "企业名称",
                      maxLines: 1,
                      style: typography.bodyStrong,
                    ))),
            NFHeader(
                flex: 1,
                child: Tooltip(
                    message: "页数(pages)",
                    child: Text(
                      "页数",
                      maxLines: 1,
                      style: typography.bodyStrong,
                    ))),
            NFHeader(
                flex: 3,
                child: Tooltip(
                    message: "错误信息",
                    child: Text(
                      "错误信息",
                      maxLines: 1,
                      style: typography.bodyStrong,
                    ))),
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
                          InfoLabel(
                            label: "文件重命名规则",
                            child: TextFormBox(
                              controller: logic.state.nameRuleTextController,
                              cursorColor: color,
                              validator: (v) {
                                if (v == '') {
                                  return "数据不能为空";
                                }
                                return null;
                              },
                            ),
                          ),
                          InfoLabel(
                              label: "编号正则配置",
                              child: _MultiText(
                                controllers: logic.state.regexTextControllers,
                                onTapOutside: (i) {
                                  debug("editing complete $i");
                                  if (logic.state.regexTextControllers[i].text
                                      .isEmpty) {
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
}

class _DataSource extends NFDataTableSource {
  final List<TarPdfResultMsg> data;
  final TarPdfController logic;

  _DataSource(this.data, this.logic);

  @override
  NFRow getRow(BuildContext context, int index) {
    final item = data[index];
    return NFRow(children: [
      Text(
        "${index + 1}",
      ),
      Text(
        item.fileName,
        maxLines: 2,
      ),
      Text(
        item.title,
        maxLines: 2,
      ),
      Text(
        item.no,
        maxLines: 2,
      ),
      Text(
        item.company,
        maxLines: 2,
      ),
      Text(
        "${item.pages}",
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      Text(
        item.errorMsg.isEmpty ? "无" : item.errorMsg,
        maxLines: 2,
        style: item.errorMsg.isEmpty ? null : TextStyle(color: Colors.red),
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
                validator: (v) {
                  bool check = false;
                  if (controllers.length == 1 || i != controllers.length - 1) {
                    check = true;
                  }
                  if (check && v == '') {
                    return "数据不能为空";
                  }
                  return null;
                },
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
