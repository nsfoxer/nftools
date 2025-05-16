import 'package:file_picker/file_picker.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:get/get.dart';
import 'package:nftools/pages/utils/controller/qr_controller.dart';
import 'package:nftools/utils/nf_widgets.dart';

class QrPage extends StatelessWidget {
  const QrPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ScaffoldPage.withPadding(
      header: const PageHeader(title: Text("二维码工具")),
      content: GetBuilder<QrController>(
          builder: (logic) => Row(
                children: [
                  Expanded(
                      flex: 1,
                      child: Column(
                        children: [
                          Expanded(
                            flex: 1,
                            child: NFCodeEditor(
                                wordWrap: true,
                                hint: "请输入要转换的文本",
                                controller:
                                    logic.state.codeLineEditingController),
                          ),
                          Expanded(
                              flex: 1,
                              child: NFCardContent(
                                  child: GestureDetector(
                                onTap: () async{
                                  final path = await _getLocalFile();
                                  if (path == null) {
                                    return;
                                  }
                                  logic.generateFile(path);
                                },
                                child: const MouseRegion(
                                  cursor: SystemMouseCursors.click,
                                  child: Center(
                                    child: Text("选取要转换的文件"),
                                  ),
                                ),
                              )))
                        ],
                      )),
                  const Divider(
                    direction: Axis.vertical,
                  ),
                  Expanded(
                      flex: 1,
                      child: NFLoadingWidgets(
                          loading: logic.state.isLoading,
                          child: Center(
                              child: logic.state.imageData.isEmpty
                                  ? null
                                  : Image(
                                      image: MemoryImage(logic.state.imageData),
                                    )))),
                ],
              )),
    );
  }

  // 获取本地文件
  Future<String?> _getLocalFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();
    return result?.files.single.path;
  }
}
