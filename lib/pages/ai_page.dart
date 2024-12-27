import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/material.dart' as $me;
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';
import 'package:markdown_widget/markdown_widget.dart';
import 'package:nftools/common/style.dart';
import 'package:nftools/controller/ai_controller.dart';
import 'package:nftools/utils/log.dart';
import 'package:nftools/utils/nf-widgets.dart';
import 'package:nftools/utils/utils.dart';
import 'package:url_launcher/link.dart';

class AiPage extends StatelessWidget {
  const AiPage({super.key});

  void _showIdList(BuildContext context) async {
    var typography = FluentTheme.of(context).typography;
    await showDialog<String>(
        barrierDismissible: true,
        context: context,
        builder: (context) => GetBuilder<AiController>(builder: (logic) {
              return ContentDialog(
                title: Text(
                  "选择对话列表",
                  style: typography.subtitle,
                ),
                content: LayoutBuilder(builder: (context, constraints) {
                  return SizedBox(
                    height: constraints.maxHeight * 0.75,
                    child: ListView.builder(
                        itemCount: logic.state.idList.length + 1,
                        itemBuilder: (context, index) {
                          if (index == 0) {
                            return Padding(
                                padding: const EdgeInsets.symmetric(
                                    vertical: NFLayout.v1,
                                    horizontal: NFLayout.v1),
                                child: Button(
                                    child: const Text("新建对话"),
                                    onPressed: () {
                                      logic.addQuestionId();
                                    }));
                          }
                          final now = logic.state.idList[index - 1];
                          return ListTile.selectable(
                            title: now.$2.isEmpty
                                ? const Text("暂无描述")
                                : Text(now.$2),
                            selected: now.$1 == logic.state.contentData.id,
                            onSelectionChange: (v) {
                              logic.selectQuestionId(now.$1);
                            },
                            trailing: FilledButton(
                                child: Icon(FluentIcons.delete),
                                onPressed: () =>
                                    logic.deleteQuestionId(now.$1)),
                          );
                        }),
                  );
                }),
              );
            }));
  }

  void _showKVSetting(BuildContext context) async {
    var typography = FluentTheme.of(context).typography;
    var color = FluentTheme.of(context).activeColor;
    await showDialog<String>(
        context: context,
        builder: (context) => GetBuilder<AiController>(builder: (logic) {
              return ContentDialog(
                title: Text(
                  "密钥管理",
                  style: typography.subtitle,
                ),
                content: SizedBox(
                  child: Form(
                    key: logic.state.formKey,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        InfoLabel(
                          label: "APP_ID",
                          child: TextFormBox(
                            controller: logic.state.appIdController,
                            cursorColor: color,
                            keyboardType: TextInputType.text,
                          ),
                        ),
                        InfoLabel(
                          label: "SECRET",
                          child: PasswordFormBox(
                            controller: logic.state.secretController,
                            cursorColor: color,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  FilledButton(
                      child: const Text("提交"),
                      onPressed: () async {
                        if (!logic.state.formKey.currentState!.validate()) {
                          return;
                        }
                        if (await logic.setKV()) {
                          info("设置成功");
                          if (context.mounted) {
                            context.pop();
                          }
                        }
                      }),
                  Button(
                      child: const Text("取消"),
                      onPressed: () {
                        logic.state.formKey.currentState!.reset();
                        context.pop();
                      })
                ],
              );
            }));
  }

  @override
  Widget build(BuildContext context) {
    final res = FluentTheme.of(context).resources;
    return ScaffoldPage(
      header: PageHeader(
        title: const Text("BaiduAI"),
        commandBar: GetBuilder<AiController>(builder: (logic) {
          final question = logic.state.contentData.description;
          return CommandBar(
            mainAxisAlignment: MainAxisAlignment.end,
            overflowItemAlignment: MainAxisAlignment.end,
            primaryItems: [
              CommandBarButton(
                  icon: const Icon(FluentIcons.account_management),
                  label: const Text("密钥管理"),
                  onPressed: () {
                    _showKVSetting(context);
                  }),
              CommandBarButton(
                  icon: const Icon($me.Icons.question_answer),
                  label: Text(question.isEmpty ? "新增对话" : question),
                  onPressed: () {
                    _showIdList(context);
                  }),
            ],
          );
        }),
      ),
      content: GetBuilder<AiController>(builder: (logic) {
        final contents = logic.state.contentData.contents;
        if (!logic.state.isLogin) {
          return Center(
            child: Link(
              // from the url_launcher package
              uri: Uri.parse('https://ai.baidu.com/ai-doc/REFERENCE/Lkru0zoz4'),
              builder: (context, open) {
                return HyperlinkButton(
                  onPressed: open,
                  child: const Text('请先输入Yi-34B-Chat密钥'),
                );
              },
            ),
          );
        }
        if (logic.state.idList.isEmpty) {
          return const Center(
            child: Text("请先建立一个新的对话"),
          );
        }
        return Column(
          children: [
            Expanded(
              flex: 8,
              child: Align(
                  alignment: Alignment.topLeft,
                  child: ListView.builder(
                      controller: logic.state.scrollController,
                      reverse: true,
                      scrollDirection: Axis.vertical,
                      shrinkWrap: true,
                      itemCount: contents.length,
                      itemBuilder: (context, index) {
                        debugPrint("$index");
                        if (index % 2 != 0) {
                          return UserDisplay(msg: contents[index]);
                        } else {
                          return AssistantDisplay(
                              data: contents[index],
                              isLoading: logic.state.isLoading && index == 0);
                        }
                      })),
            ),
            Expanded(
                flex: 2,
                child: Stack(
                  children: [
                    Shortcuts(
                        shortcuts: {
                          LogicalKeySet(LogicalKeyboardKey.control,
                              LogicalKeyboardKey.enter): _SubmitIntent(logic)
                        },
                        child: Actions(
                          actions: {
                            _SubmitIntent: CallbackAction<_SubmitIntent>(
                                onInvoke: (_SubmitIntent intent) {
                              intent.logic.quest();
                              return null;
                            })
                          },
                          child: TextBox(
                            decoration: WidgetStatePropertyAll(BoxDecoration(
                              color: res.controlFillColorInputActive,
                            )),
                            enableSuggestions: false,
                            minLines: null,
                            maxLines: null,
                            controller: logic.state.questController,
                            onSubmitted: (msg) {
                              info(msg);
                            },
                          ),
                        )),
                    Positioned(
                        right: 10,
                        bottom: 10,
                        child: Button(
                            onPressed: logic.state.isLoading
                                ? null
                                : () {
                                    logic.quest();
                                  },
                            child: const Tooltip(
                                message: "(Ctrl+Enter)",
                                child: Text("提问 "))))
                  ],
                ))
          ],
        );
      }),
    );
  }
}

// 快捷键intent
class _SubmitIntent extends Intent {
  final AiController logic;

  const _SubmitIntent(this.logic);
}

// 回复展示
class AssistantDisplay extends StatelessWidget {
  final String data;
  final bool isLoading;

  const AssistantDisplay(
      {super.key, required this.data, required this.isLoading});

  @override
  Widget build(BuildContext context) {
    Typography typography = FluentTheme.of(context).typography;
    final loadingWidget = isLoading
        ? Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Text(
                "加载中... ",
                style: typography.body,
              ),
              NFRotationWidget(
                  child: Icon(
                $me.Icons.hourglass_bottom,
                size: typography.body?.fontSize,
              )),
            ],
          )
        : Container();
    final config = isDark(context)
        ? MarkdownConfig.darkConfig.copy(configs: [
            HrConfig.darkConfig,
            H1Config(style: typography.titleLarge ?? H1Config.darkConfig.style),
            H2Config(style: typography.title ?? H2Config.darkConfig.style),
            H3Config(style: typography.subtitle ?? H3Config.darkConfig.style),
            H4Config(style: typography.bodyLarge ?? H4Config.darkConfig.style),
            H5Config(style: typography.bodyStrong ?? H5Config.darkConfig.style),
            H6Config(style: typography.body ?? H6Config.darkConfig.style),
            // PreConfig(textStyle: typography.body ?? PreConfig.darkConfig.textStyle, styleNotMatched: typography.body ?? PreConfig.darkConfig.textStyle),
            PConfig(textStyle: typography.body ?? PConfig.darkConfig.textStyle),
            CodeConfig(
                style: typography.caption ?? CodeConfig.darkConfig.style),
            BlockquoteConfig.darkConfig,
          ])
        : MarkdownConfig.defaultConfig.copy(configs: [
            H1Config(style: typography.titleLarge ?? H1Config.darkConfig.style),
            H2Config(style: typography.title ?? H2Config.darkConfig.style),
            H3Config(style: typography.subtitle ?? H3Config.darkConfig.style),
            H4Config(style: typography.bodyLarge ?? H4Config.darkConfig.style),
            H5Config(style: typography.bodyStrong ?? H5Config.darkConfig.style),
            H6Config(style: typography.body ?? H6Config.darkConfig.style),
            // PreConfig(textStyle: typography.body ?? PreConfig.darkConfig.textStyle, styleNotMatched: typography.body ?? PreConfig.darkConfig.textStyle),
            PConfig(textStyle: typography.body ?? PConfig.darkConfig.textStyle),
            CodeConfig(
                style: typography.caption ?? CodeConfig.darkConfig.style),
          ]);

    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Image(
          image: AssetImage("assets/baidu.ico"),
          width: 25,
          height: 25,
        ),
        Expanded(
            flex: 8,
            child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: NFLayout.v3,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    NFCardContent(
                      noMargin: true,
                      child: MarkdownBlock(config: config, data: data),
                    ),
                    loadingWidget
                  ],
                ))),
      ],
    );
  }
}

// 用户展示
class UserDisplay extends StatelessWidget {
  final String msg;

  const UserDisplay({super.key, required this.msg});

  @override
  Widget build(BuildContext context) {
    final res = FluentTheme.of(context).accentColor.withAlpha(75);
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        NFCardContent(color: res, child: Text(msg)),
      ],
    );
  }
}

const DATA = '''
## 二级标题

### 三级标题

#### 四级标题

##### 五级标题

###### 六级标题

这是一段普通文字：

予观夫巴陵胜状，在洞庭一湖。衔远山，吞长江，浩浩汤汤，横无际涯；朝晖夕阴，气象万千。此则岳阳楼之大观也，前人之述备矣。然则北通巫峡，南极潇湘，迁客骚人，多会于此，览物之情，得无异乎？若夫霪雨霏霏，连月不开，阴风怒号，浊浪排空；日星隐曜，山岳潜形；商旅不行，樯倾楫摧；薄暮冥冥，虎啸猿啼。登斯楼也，则有去国怀乡，忧谗畏讥，满目萧然，感极而悲者矣。至若春和景明，波澜不惊，上下天光，一碧万顷；沙鸥翔集，锦鳞游泳；岸芷汀兰，郁郁青青。而或长烟一空，皓月千里，浮光跃金，静影沉璧，渔歌互答，此乐何极！登斯楼也，则有心旷神怡，宠辱偕忘，把酒临风，其喜洋洋者矣。

这是**加粗**，*斜体*，~~删除线~~，[链接](https://blog.imalan.cn)。

这是块引用与嵌套块引用111：

> 安得广厦千万间，大庇天下寒士俱欢颜！风雨不动安如山。
> > 呜呼！何时眼前突兀见此屋，吾庐独破受冻死亦足！

情况 

这是行内代码：`int a=1;`。这是代码块：

```c++
int main(int argc , char** argv){
    std::cout << "Hello World!\n";
    return 0;
}
```

这是无序列表：

* 苹果
    * 红将军
    * 元帅
* 香蕉
* 梨

这是有序列表：

1. 打开冰箱
    1. 右手放在冰箱门拉手上
    2. 左手扶住冰箱主体
    3. 右手向后用力
2. 把大象放进冰箱
3. 关上冰箱

这是行内公式：\$m\times n\$，这是块级公式：

\$C_{m\times k}=A_{m\times n}\cdot B_{n\times k}\$

这是一张图片：


这是表格：

第一格表头 | 第二格表头
--------- | -------------
内容单元格 第一列第一格 | 内容单元格第二列第一格
内容单元格 第一列第二格 多加文字 | 内容单元格第二列第二格

水平分割线[^这是脚注]：
------

情况
''';
