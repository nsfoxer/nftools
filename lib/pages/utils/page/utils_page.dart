import 'package:fluent_ui/fluent_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:nftools/common/style.dart';
import 'package:nftools/utils/nf_widgets.dart';

import '../../../common/constants.dart';

class UtilsPage extends StatelessWidget {
  const UtilsPage({super.key});

  @override
  Widget build(BuildContext context) {
    Typography typography = FluentTheme.of(context).typography;
    return ScaffoldPage(
        header: PageHeader(
          title: Text('Utils', style: typography.title),
        ),
        content: Container(
            margin: const EdgeInsets.symmetric(horizontal: NFLayout.v0),
            child: const Wrap(
                spacing: NFLayout.v1,
                runSpacing: NFLayout.v1,
                children: [
                  _UtilsPage(url: "/utils/diffText", child: Text("文本对比")),
                ])));
  }
}

class _UtilsPage extends StatelessWidget {
  const _UtilsPage({super.key, required this.url, required this.child});

  final String url;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Button(
        child: SizedBox(
          width: 100,
          height: 80,
          child: Center(child: child),
        ),
        onPressed: () => context.push(url));
  }
}
