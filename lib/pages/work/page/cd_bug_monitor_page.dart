import 'package:fluent_ui/fluent_ui.dart';
import 'package:get/get_state_manager/src/simple/get_state.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/link.dart';

import '../../../common/style.dart';
import '../controller/cd_bug_monitor_controller.dart';

class CdBugMonitorPage extends StatelessWidget {
  const CdBugMonitorPage({super.key});

  @override
  Widget build(BuildContext context) {
    final typography = FluentTheme.of(context).typography;
    return ScaffoldPage.withPadding(
        header: PageHeader(
          title: Text("禅道bug监控"),
          commandBar: GetBuilder<CdBugMonitorController>(builder: (logic) {
            return CommandBar(
                mainAxisAlignment: MainAxisAlignment.end,
                primaryItems: [
                  CommandBarButton(
                    icon: Icon(FluentIcons.configuration_solid),
                    label: Text("配置"),
                    onPressed: () {
                      _showConfig(context);
                    },
                  ),
                  CommandBarButton(
                    icon: ToggleSwitch(
                        checked: logic.state.enableMonitor,
                        onChanged: (v) => logic.switchMonitor()),
                    label: Text("自动监测"),
                    onPressed: logic.switchMonitor,
                  ),
                  CommandBarButton(
                    icon: Icon(FluentIcons.refresh),
                    label: Text("刷新"),
                    onPressed: () async {
                      await logic.refreshBugCount();
                    },
                  ),
                ]);
          }),
        ),
        content: Center(
          child: Column(spacing: NFLayout.v1, children: [
            Text("当前bug数量", style: typography.bodyStrong),
            GetBuilder<CdBugMonitorController>(builder: (logic) {
              final count = logic.state.count;
              if (count == null) {
                return Text("未能获取bug数量",
                    style: typography.body?.copyWith(color: Colors.red));
              }
              return Link(
                  uri: Uri.parse(
                      "${logic.state.urlController.text}/zentao/my-work-task.html"),
                  builder: (context, open) {
                    return HyperlinkButton(
                        onPressed: open,
                        child: Text("$count",
                            style: typography.titleLarge?.copyWith(
                                color: count > 0 ? Colors.red : Colors.green)));
                  });
            }),
          ]),
        ));
  }

  void _showConfig(BuildContext context) async {
    var typography = FluentTheme.of(context).typography;
    await showDialog<String>(
        barrierDismissible: true,
        context: context,
        builder: (context) =>
            GetBuilder<CdBugMonitorController>(builder: (logic) {
              return ContentDialog(
                title: Text('配置', style: typography.title),
                content: SizedBox(
                  child: Form(
                    key: logic.state.formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        InfoLabel(
                            label: "禅道服务器地址",
                            child: TextFormBox(
                              controller: logic.state.urlController,
                              placeholder: "请输入禅道服务器地址",
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return '请输入禅道服务器地址';
                                }
                                if (!value.startsWith("http://") &&
                                    !value.startsWith("https://")) {
                                  return '必须以以 http:// 或 https:// 开头';
                                }
                                return null;
                              },
                            )),
                        InfoLabel(
                            label: "cookie",
                            child: TextFormBox(
                              controller: logic.state.cookieController,
                              placeholder: "cookie",
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return '不能为空';
                                }
                                return null;
                              },
                            )),
                      ],
                    ),
                  ),
                ),
                actions: [
                  FilledButton(
                      child: Text("提交"),
                      onPressed: () {
                        if (!logic.state.formKey.currentState!.validate()) {
                          return;
                        }
                        logic.setConfig();
                        if (context.mounted) {
                          context.pop();
                        }
                      }),
                  Button(
                      child: Text("取消"),
                      onPressed: () {
                        context.pop();
                      }),
                ],
              );
            }));
  }
}
