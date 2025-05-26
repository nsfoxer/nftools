import 'package:fluent_ui/fluent_ui.dart';

class TestPage extends StatelessWidget {
  TestPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ScaffoldPage.withPadding(
      header: PageHeader(
        title: Text('测试页面'),
      ),
      content: Container(),
    );
  }
}
