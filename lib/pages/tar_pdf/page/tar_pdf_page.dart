import 'package:fluent_ui/fluent_ui.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';
import 'package:nftools/common/style.dart';
import 'package:nftools/pages/tar_pdf/controller/tar_pdf_controller.dart';
import 'package:nftools/pages/tar_pdf/state/tar_pdf_state.dart';

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
            return _buildEnd(logic);
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
                  InfoLabel(
                    label: "pdf password",
                    child: PasswordBox(
                      controller: logic.state.pdfPasswordTextController,
                    ),
                  )
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

  Widget _buildEnd(TarPdfController logic) {
    final count = logic.state.ocrResult.length;
    final success = logic.state.ocrResult
        .where((element) => element.errorMsg.isEmpty)
        .length;
    final fail = count - success;
    return Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
      Text("处理已完成, 共发现$count个pdf文件,成功处理$success个,失败$fail个"),
      Expanded(
          child: ListView.builder(
              itemCount: count,
              itemBuilder: (context, index) {
                final item = logic.state.ocrResult[index];
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.center,

                );
              })),
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
                content: SizedBox(
                    child: Form(
                  key: logic.state.formKey,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
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
                          child: TextFormBox(
                            controller: logic.state.urlKeyTextController,
                            cursorColor: color,
                            keyboardType: TextInputType.text,
                            placeholder: "XXXXXXXXXXXXXXXXXXX",
                            enableSuggestions: false,
                            obscureText: true,
                            validator: (v) {
                              if (v == '') {
                                return "数据不能为空";
                              }
                              return null;
                            },
                          )),
                      InfoLabel(
                          label: "高级设置",
                          child: TextFormBox(
                            controller: logic.state.regexTextController,
                            cursorColor: color,
                            keyboardType: TextInputType.visiblePassword,
                            placeholder: "regex",
                            enableSuggestions: false,
                            validator: (v) {
                              return null;
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
                        if (await logic.config() && context.mounted) {
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
