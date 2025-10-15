import 'package:fluent_ui/fluent_ui.dart';
import 'package:get/get_state_manager/get_state_manager.dart';
import 'package:nftools/common/constants.dart';
import 'package:nftools/common/style.dart';
import 'package:nftools/pages/settings/controller/about_controller.dart';
import 'package:nftools/pages/settings/controller/auto_start_controller.dart';
import 'package:nftools/utils/nf_widgets.dart';
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
                "行为",
                style: typography.subtitle,
              ),
              _AutoStartPage(),
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
          leading: const Row(
            spacing: NFLayout.v2,
            children: [
              Icon(FluentIcons.info12),
              Text(Constants.appName),
            ],
          ),
          header: Text(
            "版本: v0.0.1-works",
          ),

          content: Column(
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
              ),
              const Text("介绍"),
              Padding(
                padding: const EdgeInsets.all(NFLayout.v1),
                child: Text(
                  "此版本属于nftools分支(work_utils)版本, 用来作为工作相关的小工具",
                  style: typography.caption,
                ),
              ),
            ],
          ));
    });
  }
}

class _AutoStartPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GetBuilder<AutoStartController>(builder: (logic) {
      return NFPanelWidget(
        leading: const Row(
          spacing: NFLayout.v2,
          children: [
            Icon(FluentIcons.power_button),
            Text(
              "开机自启",
            )
          ],
        ),
        trailing: ToggleSwitch(
            checked: logic.state.isAutoStart,
            onChanged: (v) {
              logic.toggleAutostart(v);
            }),
      );
    });
  }
}
