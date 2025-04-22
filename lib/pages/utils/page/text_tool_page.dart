import 'package:fluent_ui/fluent_ui.dart';
import 'package:get/get.dart';
import 'package:nftools/utils/nf_widgets.dart';

import '../../../common/style.dart';
import '../controller/text_tool_controller.dart';

class TextToolPage extends StatelessWidget {
  const TextToolPage({super.key});

  @override
  Widget build(BuildContext context) {
    Typography typography = FluentTheme.of(context).typography;
    return ScaffoldPage.withPadding(
      header: const PageHeader(title: Text('文本工具')),
      content: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('操作', style: typography.subtitle),
            NFLayout.vlineh2,
            GetBuilder<TextToolController>(builder: (logic) {
              return Wrap(
                  spacing: NFLayout.v2,
                  runSpacing: NFLayout.v2,
                  children: TextToolEnum.values
                      .map((e) => _EditButton(textToolEnum: e, logic: logic))
                      .toList());
            }),
            NFLayout.vlineh0,
            Expanded(
                child:
                    Row(mainAxisAlignment: MainAxisAlignment.start, children: [
              // 文本框
              Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('文本', style: typography.subtitle),
                      Expanded(child: GetBuilder<TextToolController>(
                        builder: (logic) {
                          return NFCodeEditor(
                            controller: logic.state.textEditingController,
                          );
                        },
                      )),
                    ],
                  )),
              const Divider(direction: Axis.vertical),
              // 统计框
              Expanded(
                  flex: 1,
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('统计', style: typography.subtitle),
                        Expanded(
                            child: GetBuilder<TextToolController>(
                          builder: (logic) => ListView.builder(
                              scrollDirection: Axis.vertical,
                              itemCount: logic.state.data.length,
                              itemBuilder: (BuildContext context, int index) {
                                debugPrint('build index: $index');
                                return _StatisticItem(data: logic.state.data[index], isTitle: index == 0);
                              }),
                        ))
                      ])),
            ])),
          ]),
    );
  }
}

class _EditButton extends StatelessWidget {
  final TextToolEnum textToolEnum;
  final TextToolController logic;

  const _EditButton({required this.textToolEnum, required this.logic});

  @override
  Widget build(BuildContext context) {
    return Button(
      onPressed: () => logic.operate(textToolEnum),
      child: Text(textToolEnum.desc),
    );
  }
}

class _StatisticItem extends StatelessWidget {
  final (String, String) data;
  final bool isTitle;

  const _StatisticItem({super.key, required this.data, required this.isTitle});

  @override
  Widget build(BuildContext context) {
    Typography typography = FluentTheme.of(context).typography;
    final style = isTitle ? typography.bodyStrong : typography.body;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(data.$1, style: style),
        Text(data.$2, style: style),
      ],
    );
  }
}
