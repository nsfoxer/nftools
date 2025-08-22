import 'package:fluent_ui/fluent_ui.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';
import 'package:nftools/common/style.dart';
import 'package:nftools/pages/work/controller/work_controller.dart';

import '../../../utils/log.dart';

class WorkPage extends StatelessWidget {
  const WorkPage({super.key});

  @override
  Widget build(BuildContext context) {
    Typography typography = FluentTheme.of(context).typography;
    return GetBuilder<WorkController>(
        builder: (logic) => ScaffoldPage(
            header: PageHeader(
              title: Text('主页'),
              commandBar: logic.workState.isConfigPage
                  ? null
                  : CommandBar(
                      mainAxisAlignment: MainAxisAlignment.end,
                      primaryItems: [
                          CommandBarButton(
                              icon: Icon(FluentIcons.settings),
                              label: Text("配置"),
                              onPressed: logic.startConfig),
                        ]),
            ),
            content: logic.workState.isConfigPage
                ? _buildConfig(logic)
                : _buildGoto()));
  }

  Widget _buildGoto() {
    return Container(
        margin: const EdgeInsets.symmetric(horizontal: NFLayout.v0),
        child: const Wrap(
            spacing: NFLayout.v1,
            runSpacing: NFLayout.v1,
            children: [
              _UtilsPage(url: "/userCode", child: Text("验证码获取")),
              _UtilsPage(url: "/smsLimit", child: Text("去除短信限制")),
              _UtilsPage(url: "/pwdExpireReset", child: Text("密码过期重置")),
            ]));
  }

  Widget _buildConfig(WorkController logic) {
    final form = Form(
      key: logic.workState.formKey,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          spacing: NFLayout.v0,
          children: [
            InfoLabel(
                label: "Url前缀",
                child: TextFormBox(
                  controller: logic.workState.urlTextController,
                  placeholder: "请输入url前缀",
                  validator: (value) {
                    if (value == null ||
                        (!value.startsWith("http://") &&
                            !value.startsWith("https://"))) {
                      return '应以http://或https://开头';
                    }
                    return null;
                  },
                )),
            InfoLabel(
                label: "Token",
                child: TextFormBox(
                  controller: logic.workState.tokenTextController,
                  placeholder: "请输入token",
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return '请输入token';
                    }
                    return null;
                  },
                )),
            InfoLabel(
                label: "Key",
                child: TextFormBox(
                  controller: logic.workState.keyTextController,
                  placeholder: "请输入key",
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return '请输入key';
                    }
                    return null;
                  },
                )),
            FilledButton(
              child: Text("保存"),
              onPressed: () async {
                if (!logic.workState.formKey.currentState!.validate()) {
                  return;
                }
                if (await logic.saveConfig()) {
                  info("配置保存成功");
                }
              },
            )
          ]),
    );
    return Row(
      children: [
        Expanded(flex: 1, child: Container()),
        Expanded(flex: 3, child: form),
        Expanded(flex: 1, child: Container()),
      ],
    );
  }
}

class _UtilsPage extends StatelessWidget {
  const _UtilsPage({required this.url, required this.child});

  final String url;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Button(
        child: SizedBox(
          width: 100,
          height: 80,
          child: Center(child: child),
        ),
        onPressed: () => context.replace(url));
  }
}
