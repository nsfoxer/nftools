import 'package:fluent_ui/fluent_ui.dart';

// 空白页面
class EmptyPage extends StatelessWidget {
  const EmptyPage({super.key});

  @override
  Widget build(BuildContext context) {
    var typography = FluentTheme.of(context).typography;
    return Center(
      child: Text(
        "暂未开发",
        style: typography.title,
      ),
    );
  }
}
