import 'dart:math';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';
import 'package:nftools/controller/ai_controller.dart';
import 'package:nftools/utils/log.dart';

class AiPage extends StatelessWidget {
  const AiPage({super.key});

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
                            validator: (v) {
                              return null;
                            },
                          ),
                        ),
                        InfoLabel(
                          label: "SECRET",
                          child: PasswordFormBox(
                            controller: logic.state.secretController,
                            cursorColor: color,
                            validator: (v) {
                              return null;
                            },
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

  void _submit() {}

  @override
  Widget build(BuildContext context) {
    final res = FluentTheme.of(context).resources;
    return ScaffoldPage(
      header: PageHeader(
        title: const Text("BaiduAI"),
        commandBar: GetBuilder<AiController>(builder: (logic) {
          return CommandBar(
            mainAxisAlignment: MainAxisAlignment.end,
            overflowItemAlignment: MainAxisAlignment.end,
            primaryItems: [
              CommandBarButton(
                  icon: const Icon(FluentIcons.account_management),
                  label: const Text("账户管理"),
                  onPressed: () {
                    _showKVSetting(context);
                  }),
              CommandBarButton(
                  icon: const Icon(FluentIcons.refresh),
                  label: const Text("刷新"),
                  onPressed: () {}),
            ],
          );
        }),
      ),
      content: GetBuilder<AiController>(builder: (logic) {
        return Column(
          children: [
            Expanded(
              flex: 8,
              child: TextBox(
                readOnly: true,
                maxLines: null,
                maxLength: null,
                foregroundDecoration: const WidgetStatePropertyAll(
                    BoxDecoration(
                        border: Border.fromBorderSide(BorderSide.none))),
                decoration: WidgetStatePropertyAll(BoxDecoration(
                  color: res.controlFillColorSecondary,
                )),
                controller: logic.state.displayController,
              ),
            ),
            Expanded(
                flex: 2,
                child: Stack(
                  children: [
                    Shortcuts(
                        shortcuts: {
                          LogicalKeySet(LogicalKeyboardKey.alt,
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
                            onPressed: () {
                              logic.quest();
                            },
                            child: const Text("提问")))
                  ],
                ))
          ],
        );
      }),
    );
  }
}

class _SubmitIntent extends Intent {
  final AiController logic;
  const _SubmitIntent(this.logic);
}
