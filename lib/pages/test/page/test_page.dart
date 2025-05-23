import 'package:fluent_ui/fluent_ui.dart';
import 'package:re_editor/re_editor.dart';

class TestPage extends StatelessWidget {
  TestPage({super.key});

  final FocusNode _focusNode = FocusNode();

  @override
  Widget build(BuildContext context) {
    return ScaffoldPage.withPadding(
      header: PageHeader(
        title: Text('测试页面'),
      ),
      content: CodeEditor(
        focusNode: _focusNode,
        autofocus: true,
        readOnly: true,
      ),
    );
  }
}
