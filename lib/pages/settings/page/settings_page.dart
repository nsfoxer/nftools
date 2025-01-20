import 'dart:math';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:get/get_state_manager/get_state_manager.dart';
import 'package:nftools/pages/settings/controller/about_controller.dart';

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
              Text("关于", style: typography.subtitle,),
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
    return GetBuilder<AboutController>(builder: (logic)  {
      return Expander(
        leading: const Icon(FluentIcons.info12),
        header: InfoLabel(label: "nftools", child: Text("当前版本： ${logic.state.version}", style: typography.caption,)),
        content: Text('This text is in content'),
      );
    });
  }
}
