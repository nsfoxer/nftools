import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/material.dart' as $me;
import 'package:get/get.dart';
import 'package:nftools/common/constants.dart';
import 'package:nftools/pages/utils/controller/text_diff_controller.dart';
import 'package:nftools/utils/nf_widgets.dart';
import 'package:pretty_diff_text/pretty_diff_text.dart';
import 'package:re_editor/re_editor.dart';

final ScrollController _hScrollController = ScrollController();
final ScrollController _vScrollController = ScrollController();

class TextDiffPage extends StatelessWidget {
  const TextDiffPage({super.key});

  @override
  Widget build(BuildContext context) {
    Typography typography = FluentTheme.of(context).typography;
    return ScaffoldPage(
      header: PageHeader(
        title: Text('文本对比', style: typography.title),
      ),
      content: GetBuilder<TextDiffController>(
          builder: (logic) => Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                      flex: 3,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                              flex: 20,
                              child: _CodeEditor(
                                  codeLineEditingController:
                                      logic.state.oldTextEditingController,
                                  readOnly: false)),
                          const $me.VerticalDivider(),
                          Expanded(
                            flex: 20,
                            child: _CodeEditor(
                                codeLineEditingController:
                                    logic.state.newTextEditingController,
                                readOnly: false),
                          ),
                        ],
                      )),
                  Expanded(
                      flex: 7,
                      child: NFCardContent(
                        child: Scrollbar(
                          controller: _vScrollController,
                          child: SingleChildScrollView(
                            controller: _vScrollController,
                            scrollDirection: Axis.horizontal,
                            child: SingleChildScrollView(
                                controller: _hScrollController,
                                scrollDirection: Axis.vertical,
                                child: Container(
                                    constraints: const BoxConstraints(
                                      minWidth: 6000,
                                    ),
                                    child: GetBuilder<TextDiffController>(
                                        id: PageWidgetNameConstant
                                            .textDiffTextPrettyDiffText,
                                        builder: (logic) => PrettyDiffText(
                                              overflow: TextOverflow.ellipsis,
                                              oldText: logic
                                                  .state
                                                  .oldTextEditingController
                                                  .text,
                                              newText: logic
                                                  .state
                                                  .newTextEditingController
                                                  .text,
                                              softWrap: false,
                                              defaultTextStyle:
                                                  typography.body!,
                                              diffCleanupType:
                                                  DiffCleanupType.EFFICIENCY,
                                            )))),
                          ),
                        ),
                      )),
                ],
              )),
    );
  }
}

// 代码编辑器
class _CodeEditor extends StatelessWidget {
  final CodeLineEditingController codeLineEditingController;
  final bool readOnly;

  const _CodeEditor(
      {super.key,
      required this.codeLineEditingController,
      required this.readOnly});

  @override
  Widget build(BuildContext context) {
    return NFCardContent(
        child: CodeEditor(
      wordWrap: false,
      controller: codeLineEditingController,
      readOnly: readOnly,
      indicatorBuilder:
          (context, editingController, chunkController, notifier) {
        return Row(
          children: [
            DefaultCodeLineNumber(
              controller: editingController,
              notifier: notifier,
              minNumberCount: 0,
            ),
            DefaultCodeChunkIndicator(
                width: 5, controller: chunkController, notifier: notifier)
          ],
        );
      },
    ));
  }
}
