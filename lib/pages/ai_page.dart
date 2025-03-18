import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/material.dart' as $me;
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';
import 'package:markdown_widget/markdown_widget.dart';
import 'package:nftools/common/style.dart';
import 'package:nftools/controller/ai_controller.dart';
import 'package:nftools/messages/ai.pb.dart';
import 'package:nftools/utils/log.dart';
import 'package:nftools/utils/nf_widgets.dart';
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
                                    onPressed: () async {
                                      await logic.addQuestionId();
                                      if (context.mounted) {
                                        context.pop();
                                      }
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
                                child: const Icon(FluentIcons.delete),
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
    final typography = FluentTheme.of(context).typography;
    final color = primaryColor(context);
    await showDialog<String>(
        context: context,
        builder: (context) => GetBuilder<AiController>(builder: (logic) {
              final bool isBaidu = logic.state.modelEnum == ModelEnum.Baidu;
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
                        isBaidu
                            ? InfoLabel(
                                label: "SECRET",
                                child: PasswordFormBox(
                                  controller: logic.state.secretController,
                                  cursorColor: color,
                                ),
                              )
                            : Container(),
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
    final color = primaryColor(context);
    return ScaffoldPage(
      header: PageHeader(
        title: const Text("AI"),
        commandBar: GetBuilder<AiController>(builder: (logic) {
          final question = logic.state.contentData.description;
          return CommandBar(
            mainAxisAlignment: MainAxisAlignment.end,
            overflowItemAlignment: MainAxisAlignment.end,
            primaryItems: [
              CommandBarButton(
                  icon: const Icon($me.Icons.key),
                  label: const Text("密钥"),
                  onPressed: logic.state.isLoading
                      ? null
                      : () {
                          _showKVSetting(context);
                        }),
              CommandBarButton(
                  icon: const Icon($me.Icons.question_answer),
                  label: Text(question.isEmpty ? "新增对话" : question),
                  onPressed: logic.state.isLoading
                      ? null
                      : () {
                          _showIdList(context);
                        }),
              // 禁用掉百度的API start ============
              // CommandBarButton(
              //   icon: const Icon($me.Icons.model_training),
              //   label: Text(logic.state.modelEnum.toString()),
              //   onPressed: logic.state.isLoading
              //       ? null
              //       : () {
              //           logic.changeModel();
              //         },
              // ),
              // 禁用掉百度的API end ============
            ],
          );
        }),
      ),
      content: GetBuilder<AiController>(builder: (logic) {
        final bool isBaidu = logic.state.modelEnum == ModelEnum.Baidu;
        final contents = logic.state.contentData.contents;
        if (!logic.state.isLogin) {
          return Center(
            child: Link(
              // from the url_launcher package
              uri: isBaidu
                  ? Uri.parse('https://ai.baidu.com/ai-doc/REFERENCE/Lkru0zoz4')
                  : Uri.parse(
                      "https://www.xfyun.cn/doc/spark/HTTP%E8%B0%83%E7%94%A8%E6%96%87%E6%A1%A3.html"),
              builder: (context, open) {
                return HyperlinkButton(
                  onPressed: open,
                  child: isBaidu
                      ? const Text('请先输入Yi-34B-Chat密钥')
                      : const Text("请先输入spark密钥"),
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
                        if (index % 2 != 0) {
                          return UserDisplay(msg: contents[index]);
                        } else {
                          return AssistantDisplay(
                              isBaidu: isBaidu,
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
                              if (!logic.state.isLoading) {
                                intent.logic.quest();
                              }
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
                            cursorColor: color,
                            controller: logic.state.questController,
                          ),
                        )),
                    Positioned(
                        right: 10,
                        bottom: 10,
                        child: logic.state.isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: ProgressRing(),
                              )
                            : Button(
                                onPressed: () {
                                  logic.quest();
                                },
                                child: const Tooltip(
                                    message: "(Ctrl+Enter)",
                                    child: Text("提问"))))
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

final _sparkLogo = SvgPicture.asset(
  "assets/img/spark.svg",
  width: 25,
  height: 25,
);

// 回复展示
class AssistantDisplay extends StatelessWidget {
  final String data;
  final bool isLoading;
  final bool isBaidu;

  const AssistantDisplay(
      {super.key,
      required this.data,
      required this.isLoading,
      required this.isBaidu});

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
              // NFRotationWidget(
              //     child: Icon(
              //   $me.Icons.hourglass_bottom,
              //   size: typography.body?.fontSize,
              // )),
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
        isBaidu
            ? const Image(
                image: AssetImage("assets/img/baidu.ico"),
                width: 25,
                height: 25,
              )
            : _sparkLogo,
        Expanded(
            flex: 8,
            child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  NFLayout.v3,
                  0,
                  NFLayout.v3 * 4,
                  NFLayout.v3,
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
        NFCardContent(color: res, child: SelectableText(msg)),
      ],
    );
  }
}
