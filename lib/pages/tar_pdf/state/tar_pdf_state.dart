import 'package:fluent_ui/fluent_ui.dart';
import 'package:nftools/src/bindings/bindings.dart';

class TarPdfState {
  bool isProcess = false;
  DisplayProcessEnum processEnum = DisplayProcessEnum.start;

  int sum = 0;
  int current = 0;
  List<TarPdfResultMsg> ocrResult = [];

  TextEditingController pdfDirTextController = TextEditingController();
  TextEditingController pdfPasswordTextController = TextEditingController();

  // 配置文本输入框
  GlobalKey<FormState> formKey = GlobalKey();
  TextEditingController urlTextController = TextEditingController();
  TextEditingController urlKeyTextController = TextEditingController();
  TextEditingController regexTextController = TextEditingController();

  void reset() {
    isProcess = false;
    processEnum = DisplayProcessEnum.start;
    sum = 0;
    current = 0;
    ocrResult.clear();
    pdfDirTextController.clear();
    pdfPasswordTextController.clear();
  }
}

enum DisplayProcessEnum {
  start,
  processing,
  end
}