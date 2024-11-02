import 'package:fluent_ui/fluent_ui.dart';

class EmptyPage extends StatelessWidget {
  const EmptyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ScaffoldPage.scrollable(
      header: const PageHeader(
        title: Text("暂未实现"),
      ),
      children: [],
    );
  }
}
