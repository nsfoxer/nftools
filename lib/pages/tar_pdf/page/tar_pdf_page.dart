import 'package:fluent_ui/fluent_ui.dart';
import 'package:get/get.dart';
import 'package:nftools/common/style.dart';
import 'package:nftools/pages/tar_pdf/controller/tar_pdf_controller.dart';
import 'package:nftools/pages/tar_pdf/state/tar_pdf_state.dart';

class TarPdfPage extends StatelessWidget {
  const TarPdfPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ScaffoldPage.withPadding(
      header: PageHeader(
        title: Text('PDF归档'),
        commandBar: GetBuilder<TarPdfController>(
            builder: (logic) => CommandBar(
                  mainAxisAlignment: MainAxisAlignment.end,
                  primaryItems: [
                    CommandBarButton(
                      icon: const Icon(FluentIcons.step),
                      label: const Text('start'),
                      onPressed: () {
                        logic.start();
                      },
                    ),
                    CommandBarButton(
                      icon: const Icon(FluentIcons.reset),
                      label: const Text('reset'),
                      onPressed: logic.reset,
                    ),
                  ],
                )),
      ),
      content: GetBuilder<TarPdfController>(builder: (logic) {
        switch (logic.state.processEnum) {
          case DisplayProcessEnum.start:
            return _buildStart(logic);
          case DisplayProcessEnum.processing:
            return _buildProcessing(logic);
          case DisplayProcessEnum.end:
            return _buildEnd(logic);
        }
      }),
    );
  }

  Widget _buildStart(TarPdfController logic) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(flex: 1, child: Container()),
        Expanded(
            flex: 3,
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: NFLayout.v0,
                children: [
                  InfoLabel(
                    label: "请选择pdf存储路径",
                    child: TextBox(
                      maxLines: 1,
                      readOnly: true,
                      onTap: logic.selectPdfDir,
                      controller: logic.state.pdfDirTextController,
                    ),
                  ),
                  InfoLabel(
                    label: "pdf password",
                    child: PasswordBox(
                      controller: logic.state.pdfPasswordTextController,
                    ),
                  )
                ])),
        Expanded(flex: 1, child: Container()),
      ],
    );
  }

  Widget _buildProcessing(TarPdfController logic) {
    return Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
      Expanded(flex: 1, child: Container()),
      Expanded(
          flex: 3,
          child: Center(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.center,
                  spacing: NFLayout.v0,
                  children: [
                Text(
                  "processing...   ${logic.state.current}/${logic.state.sum}",
                ),
                ProgressBar(
                    value: logic.state.sum == 0
                        ? 0
                        : logic.state.current / logic.state.sum * 100),
              ]))),
      Expanded(
        flex: 1,
        child: Container(),
      ),
    ]);
  }

  Widget _buildEnd(TarPdfController logic) {
    return ListView.builder(
      itemCount: logic.state.result.length,
      itemBuilder: (context, index) {
        return ListTile.selectable(
          title: Text(logic.state.result[index]),
        );
      },
    );
  }

}
