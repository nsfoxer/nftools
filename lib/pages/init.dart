import 'package:fluent_ui/fluent_ui.dart';

/// 页面初始化组件
class InitPage extends StatelessWidget {
  const InitPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const NavigationView(
      content: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text("正在初始化..."),
            ProgressRing(),
          ],
        ),
      ),
    );
  }
}