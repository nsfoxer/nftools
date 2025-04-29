import 'package:fluent_ui/fluent_ui.dart';
import 'package:nftools/utils/nf_widgets.dart';

import '../common/style.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return ScaffoldPage.withPadding(
      header: const PageHeader(
        title: Text("主页"),
      ),
      content: const Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("欢迎使用 NF Tools!"),
          NFLayout.vlineh2,
          Text("这是一个简单的工具集合，主要是我自己使用的工具。"),
          NFLayout.vlineh2,
          Text("目前支持的工具如下："),
          NFLayout.vlineh2,
          Padding(padding: EdgeInsets.symmetric(horizontal: NFLayout.v0), child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(" -   系统显示工具"),
              Text(" -   文件同步工具（WebDav）"),
              Text(" -   AI对话工具（Spark Lite）"),
              Text(" -   文本常用工具"),
            ]
          )),
          NFLayout.vlineh2,
          Text("后续会增加更多的工具，敬请期待！"),
        ],
      ),
    );
  }
}
