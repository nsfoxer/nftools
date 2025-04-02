import 'package:fluent_ui/fluent_ui.dart';
import 'package:pretty_diff_text/pretty_diff_text.dart';

final _old = """
I'm a old text
Two
3
""";
final _new = """
I'm a new text
2
Three
""";

class UtilsPage extends StatelessWidget {
  const UtilsPage({super.key});

  @override
  Widget build(BuildContext context) {
    Typography typography = FluentTheme.of(context).typography;
    return ScaffoldPage(
      header: PageHeader(
        title: Text('Utils', style: typography.title),
      ),
      content: PrettyDiffText(
        oldText: _old,
        newText: _new,
        defaultTextStyle: typography.body!,
        diffCleanupType: DiffCleanupType.NONE,
      ),
    );
  }

}