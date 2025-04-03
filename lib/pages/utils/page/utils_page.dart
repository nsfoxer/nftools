import 'package:fluent_ui/fluent_ui.dart';
import 'package:nftools/utils/nf_widgets.dart';

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
              NFCardContent(
                  child: SizedBox(
                      width: 100,
                      height: 80,
                      child: Center(child: Text("文本对比"))))
            ]));
  }
}
