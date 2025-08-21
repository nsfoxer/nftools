import 'package:fluent_ui/fluent_ui.dart';

class SmsLimitPage extends StatelessWidget {
  const SmsLimitPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ScaffoldPage.withPadding(
      header: PageHeader(title: Text("短信限制")),
      content: Center(
        child: Text("开发中"),
      ),
    );
  }
}