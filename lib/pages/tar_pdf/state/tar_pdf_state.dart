import 'package:fluent_ui/fluent_ui.dart';
import 'package:nftools/src/bindings/bindings.dart';

import '../../../utils/log.dart';

class TarPdfState {
  bool isProcess = false;
  DisplayProcessEnum processEnum = DisplayProcessEnum.start;

  // 处理中展示数据
  int sum = 0;
  int current = 0;
  List<TarPdfResultMsg> ocrResult = [];

  // 地址框
  TextEditingController pdfDirTextController = TextEditingController();

  // 配置文本输入框
  GlobalKey<FormState> formKey = GlobalKey();
  TextEditingController urlTextController = TextEditingController();
  TextEditingController apiKeyTextController = TextEditingController();
  TextEditingController pdfPasswordTextController = TextEditingController();
  List<TextEditingController> regexTextControllers = [TextEditingController()];

  void reset() {
    isProcess = false;
    processEnum = DisplayProcessEnum.start;
    sum = 0;
    current = 0;
    ocrResult.clear();
    pdfDirTextController.clear();
    pdfPasswordTextController.clear();

    for (var element in regexTextControllers) {
      element.dispose();
    }
    regexTextControllers = [TextEditingController()];

  }


}

enum DisplayProcessEnum { start, processing, end }
