import 'dart:math';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:get/get_state_manager/get_state_manager.dart';
import 'package:nftools/pages/settings/controller/about_controller.dart';
import 'package:nftools/utils/log.dart';
import 'package:url_launcher/link.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    Typography typography = FluentTheme.of(context).typography;
    return ScaffoldPage.scrollable(
        header: const PageHeader(
          title: Text("设置"),
        ),
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "关于",
                style: typography.subtitle,
              ),
              _AboutPage(),
            ],
          )
        ]);
  }
}

class _AboutPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    Typography typography = FluentTheme.of(context).typography;
    return GetBuilder<AboutController>(builder: (logic) {
      return Expander(
          leading: const Icon(FluentIcons.info12),
          header: InfoLabel(
              label: "nftools",
              child: Text(
                "当前版本： ${logic.state.version}",
                style: typography.caption,
              )),
          trailing: () {
            if (logic.state.version != logic.state.newestVersion) {
              return null;
            }
            if (logic.state.isInstalling) {
              return const Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [Text("下载中  "), ProgressBar()],
              );
            }
            return FilledButton(
                child: Text(
                  "最新版本: ${logic.state.newestVersion}",
                  style: typography.body,
                ),
                onPressed: () {
                  logic.installNewest();
                });
          }(),
          content: Column(
            // mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("作者"),
              Link(
                uri: Uri.parse("https://www.cnblogs.com/nsfoxer"),
                builder: (context, open) {
                  return HyperlinkButton(
                    onPressed: open,
                    child: const Text("nsfoxer"),
                  );
                },
              ),
              const Text("项目地址"),
              Link(
                uri: Uri.parse("https://gitee.com/muwuren/nftools"),
                builder: (context, open) {
                  return HyperlinkButton(
                    onPressed: open,
                    child: const Text("https://gitee.com/muwuren/nftools"),
                  );
                },
              )
            ],
          ));
    });
  }
}
