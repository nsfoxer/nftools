import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/material.dart' as $me;

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
              Expander(
                leading: Icon(FluentIcons.info12),
                header: InfoLabel(label: "nftools", child: Text("版本"),),
                content: Text('This text is in content'),
              ),
            ],
          )
        ]);
  }
}

class _AboutPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    throw UnimplementedError();
  }
}
