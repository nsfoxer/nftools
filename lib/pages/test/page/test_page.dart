import 'package:fluent_ui/fluent_ui.dart';
import 'package:nftools/utils/log.dart';
import 'package:nftools/utils/utils.dart';


class TestPage extends StatelessWidget {

  const TestPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ScaffoldPage.withPadding(
        header: PageHeader(title: const Text("测试")),
        content:
        Center(
          child: Button(child: Text("测试"), onPressed: () async {
            final d = await confirmDialog2(context, "aaa", "sss");
            debug("d $d");
          }),
        )

    );
  }
}
