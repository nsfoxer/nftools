import 'package:fluent_ui/fluent_ui.dart';

class UtilsPage extends StatelessWidget {
  const UtilsPage({super.key});

  @override
  Widget build(BuildContext context) {
    Typography typography = FluentTheme.of(context).typography;
    return ScaffoldPage(
      header: PageHeader(
        title: Text('Utils', style: typography.title),
      ),
      content: const Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("文本对比")
        ]
      )
    );
  }

}