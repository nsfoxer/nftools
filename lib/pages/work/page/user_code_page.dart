import 'package:fluent_ui/fluent_ui.dart';
import 'package:get/get.dart';
import 'package:nftools/common/style.dart';
import 'package:nftools/pages/work/controller/user_code_controller.dart';
import 'package:nftools/pages/work/state/user_code_state.dart';
import 'package:nftools/utils/nf_widgets.dart';
import 'package:pasteboard/pasteboard.dart';

import '../../../utils/log.dart';

class UserCodePage extends StatelessWidget {
  const UserCodePage({super.key});

  @override
  Widget build(BuildContext context) {
    final typography = FluentTheme.of(context).typography;
    return ScaffoldPage.withPadding(
        header: PageHeader(
          title: Text("验证码获取"),
          commandBar: GetBuilder<UserCodeController>(
              builder: (logic) => CommandBar(
                      mainAxisAlignment: MainAxisAlignment.end,
                      primaryItems: [
                        CommandBarButton(
                          icon: Icon(FluentIcons.refresh),
                          label: Text("刷新"),
                          onPressed: logic.refreshData,
                        ),
                      ])),
        ),
        content: GetBuilder<UserCodeController>(
            builder: (logic) => NFLoadingWidgets(
                loading: logic.state.isLoading,
                child: NFTable(
                  empty: logic.dio == null ? Text("请先配置网络"): Text("暂无数据"),
                  header: [
                    NFHeader(flex: 1, child: Text("序号")),
                    NFHeader(flex: 2, child: Text("用户名")),
                    NFHeader(flex: 2, child: Text("验证码")),
                    NFHeader(flex: 2, child: Text("剩余有效期")),
                  ],
                  minWidth: 400,
                  prototypeItem: NFRow(
                      children: [Text("Some", style: typography.bodyStrong)]),
                  source: _UserCodeDataSource(logic.state.data),
                ))));
  }

}

class _UserCodeDataSource extends NFDataTableSource {
  final List<UserCodeData> data;

  _UserCodeDataSource(this.data);

  @override
  NFRow getRow(BuildContext context, int index) {
    final typography = FluentTheme.of(context).typography;
    return NFRow(children: [
      Text("${index+1}"),
      Text(data[index].accountId),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        spacing: NFLayout.v3,
        children: [
          Text(data[index].code),
          IconButton(icon:Icon(FluentIcons.copy, size: typography.caption?.fontSize), onPressed: () {
            Pasteboard.writeText(data[index].code);
            info("已复制");
          },),
        ],
      ),

      Text(_formatSeconds(data[index].expireTime)),
    ]);
  }

  @override
  bool get isEmpty => data.isEmpty;

  @override
  int? get itemCount => data.length;

  static String _formatSeconds(int seconds) {
    if (seconds < 60) {
      return '${seconds}s';
    } else {
      int minutes = seconds ~/ 60;
      int remainingSeconds = seconds % 60;
      // 处理剩余秒数为0的情况
      if (remainingSeconds == 0) {
        return '${minutes}min';
      }
      return '${minutes}min ${remainingSeconds}s';
    }
  }
}
