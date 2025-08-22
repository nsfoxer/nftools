import 'package:fluent_ui/fluent_ui.dart';
import 'package:get/get.dart';

import '../../../utils/nf_widgets.dart';
import '../controller/sms_limit_controller.dart';
import '../state/sms_limit_state.dart';

class SmsLimitPage extends StatelessWidget {
  const SmsLimitPage({super.key});

  @override
  Widget build(BuildContext context) {
    final typography = FluentTheme.of(context).typography;
    return ScaffoldPage.withPadding(
        header: PageHeader(
          title: Text("验证码获取"),
          commandBar: GetBuilder<SmsLimitController>(
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
        content: GetBuilder<SmsLimitController>(
            builder: (logic) => NFLoadingWidgets(
                loading: logic.state.isLoading,
                child: NFTable(
                  empty: logic.dio == null ? Text("请先配置网络"): Text("暂无数据"),
                  header: [
                    NFHeader(flex: 1, child: Text("序号")),
                    NFHeader(flex: 2, child: Text("手机号")),
                    NFHeader(flex: 2, child: Text("今日发送次数")),
                    NFHeader(flex: 2, child: Text("操作")),
                  ],
                  minWidth: 400,
                  prototypeItem: NFRow(
                      children: [Text("Some", style: typography.bodyStrong)]),
                  source: _SmsLimitDataSource(logic.state.data, logic),
                ))));
  }
}

class _SmsLimitDataSource extends NFDataTableSource {
  final List<SmsLimitData> data;
  final SmsLimitController logic;

  _SmsLimitDataSource(this.data, this.logic);

  @override
  NFRow getRow(BuildContext context, int index) {
    return NFRow(children: [
      Text("${index+1}"),
      Text(data[index].phone),
      Text(data[index].count.toString()),
      IconButton(icon: Icon(FluentIcons.delete), onPressed: () {
        logic.deleteSmsLimit(data[index].phone);
      })
    ]);
  }

  @override
  bool get isEmpty => data.isEmpty;

  @override
  int? get itemCount => data.length;



}
