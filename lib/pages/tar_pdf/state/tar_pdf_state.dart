
import 'dart:typed_data';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:nftools/src/bindings/bindings.dart';
import 'package:nftools/utils/nf_widgets.dart';


class TarPdfState {
  bool isLoading = false;
  DisplayProcessEnum processEnum = DisplayProcessEnum.order1;

  // 处理中展示数据
  int sum = 0;
  int current = 0;
  List<TarPdfResultMsg> ocrResult = [];

  // 配置框是否正在加载
  bool isConfigLoading = false;

  // 地址框
  TextEditingController pdfDirTextController = TextEditingController();

  // 配置文本输入框
  GlobalKey<FormState> formKey = GlobalKey();
  TextEditingController urlTextController = TextEditingController();
  TextEditingController apiKeyTextController = TextEditingController();
  TextEditingController pdfPasswordTextController = TextEditingController();
  TextEditingController nameRuleTextController = TextEditingController();
  List<TextEditingController> regexTextControllers = [TextEditingController()];

  // 是否可导出
  bool canExport = false;

  // order2
  List<String> pdfFiles = [];

  // order3
  bool isRefOcrLoading = false;
  List<OcrDataMsg> refOcrDatas = [];
  NFImagePainterController refImagePainterController = NFImagePainterController();

  // order3 选中标签框
  Set<String> selectedTags = {};


  void reset() {
    isLoading = false;
    processEnum = DisplayProcessEnum.order1;
    sum = 0;
    current = 0;
    ocrResult.clear();
    pdfDirTextController.clear();
    pdfPasswordTextController.clear();
    nameRuleTextController.clear();
    isConfigLoading = false;
    pdfFiles.clear();
    refOcrDatas.clear();
    refImagePainterController.reset();

    for (var element in regexTextControllers) {
      element.dispose();
    }
    regexTextControllers = [TextEditingController()];
    canExport = false;
  }

}

enum DisplayProcessEnum {
  order1(1, "选择文件夹"),
  order2(2, "选择参考文件"),
  order3(3, "选取参考文字"),
  order4(4, "处理中"),
  order5(5, "处理结果展示");


  const DisplayProcessEnum(this.value, this.desc);
  final String desc;
  final int value;

  static DisplayProcessEnum? fromValue(int value) {
    for (var element in DisplayProcessEnum.values) {
      if (element.value == value) {
        return element;
      }
    }
    return null;
  }

  DisplayProcessEnum? next() {
    return DisplayProcessEnum.fromValue(value + 1);
  }

  DisplayProcessEnum? pre() {
    return DisplayProcessEnum.fromValue(value - 1);
  }
}
