import 'package:file_picker/file_picker.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:get/get_state_manager/src/simple/get_controllers.dart';
import 'package:nftools/pages/tar_pdf/state/tar_pdf_state.dart';
import 'package:nftools/src/bindings/signals/signals.dart';
import 'package:nftools/utils/extension.dart';
import 'package:nftools/utils/log.dart';

import '../api/api.dart' as $api;

class TarPdfController extends GetxController with GetxUpdateMixin {
  TarPdfState state = TarPdfState();


  @override
  void onReady() {
    _init();
    super.onReady();
  }

  void _init() async {
    configReset();
  }

  void _start() {
    state.isLoading = true;
    update();
  }

  void _end() {
    state.isLoading = false;
    update();
  }

  void selectPdfDir() async {
    final path = await FilePicker.platform.getDirectoryPath();
    if (path == null) {
      return;
    }
    state.pdfDirTextController.text = path;
    update();
  }

  // 开始处理
  void start() async {
    final Stream<TarPdfMsg> stream;
    try {
      stream = $api.handle(state.pdfDirTextController.text);
    } catch (e) {
      return;
    }

    // state.processEnum = DisplayProcessEnum.processing;
    update();
    stream.listen((data) {
      state.sum = data.sum;
      state.current = data.now;
      update();
    }, onDone: () {
      _end();
    }, onError: (e) {
      error(e.toString());
      // state.processEnum = DisplayProcessEnum.start;
      update();
    }, cancelOnError: true);
  }

  // 结束处理
  void _end2() async {
    // state.processEnum = DisplayProcessEnum.end;
    state.ocrResult = await $api.ocrResult();
    state.canExport = true;
    update();
  }

  void reset() async {
    state.reset();
    await $api.clearResult();
    await configReset();
    update();
  }

  Future<void> configReset() async {
    final OcrConfigMsg config;
    try {
      config = await $api.getConfig();
    } on Exception catch (e) {
      debug(e.toString());
      warn("OCR服务未配置,请先配置!");
      return;
    }

    state.urlTextController.text = config.url;
    state.apiKeyTextController.text = config.apiKey;
    state.pdfPasswordTextController.text = config.passwd ?? "";
    state.nameRuleTextController.text = config.exportFileNameRule;

    for (var element in state.regexTextControllers) {
      element.dispose();
    }
    state.regexTextControllers.clear();
    for (var element in config.noRegex) {
      state.regexTextControllers.add(TextEditingController(text: element));
    }
    trySupplyNewText();
  }

  Future<bool> setConfig() async {
    final url = state.urlTextController.text;
    final urlKey = state.apiKeyTextController.text;
    final passwd = state.pdfPasswordTextController.text;
    final nameRule = state.nameRuleTextController.text;
    final regex = state.regexTextControllers.map((e) => e.text).toList();
    regex.removeWhere((element) => element.isEmpty);

    if (url.isEmpty || urlKey.isEmpty || regex.isEmpty || nameRule.isEmpty) {
      error("请补全配置");
      return false;
    }

    state.isConfigLoading = true;
    update();

    try {
      await $api.setConfig(url, urlKey, regex, passwd, nameRule);
    } catch (e) {
      error("服务器配置失败,请检查配置!");
      state.isConfigLoading = false;
      update();
      return false;
    }

    try {
      await $api.ocrCheck();
    } catch (e) {
      error("文字识别服务检查失败,请检查配置!");
      state.isConfigLoading = false;
      update();
      return false;
    }
    info("服务器配置成功");
    state.isConfigLoading = false;
    update();
    return true;
  }


  // 添加正则输入框
  void trySupplyNewText() {
    if (state.regexTextControllers.isEmpty) {
      state.regexTextControllers.add(TextEditingController());
    } else if (state.regexTextControllers.last.text.isNotEmpty) {
      state.regexTextControllers.add(TextEditingController());
    }
    update();
  }

  // 移除正则输入框
  void removeRegex(int i) {
    if (i < 0 || i > state.regexTextControllers.length - 1) {
      fatal("移除输入框索引越界");
      return;
    }

    if (state.regexTextControllers.length > 1) {
      final controller = state.regexTextControllers.removeAt(i);
      controller.dispose();
    }
    trySupplyNewText();
  }

  void exportResult() async {
    final file = await $api.exportResult();
    state.canExport = false;
    update();
    info("导出成功,文件路径:$file");
  }

  // 下一步
  void next() {
    switch (state.processEnum) {
      case DisplayProcessEnum.order1:
        _nextOrder1();
        return;
      case DisplayProcessEnum.order2:
        // TODO: Handle this case.
        throw UnimplementedError();
      case DisplayProcessEnum.order3:
        // TODO: Handle this case.
        throw UnimplementedError();
      case DisplayProcessEnum.order4:
        // TODO: Handle this case.
        throw UnimplementedError();
      case DisplayProcessEnum.order5:
        // TODO: Handle this case.
        throw UnimplementedError();
    }
  }

  void _nextOrder1() async {
    if (state.pdfDirTextController.text.isEmpty) {
      error("请选择PDF目录");
      return;
    }
    _start();

    try {
      state.pdfFiles = await $api.listDirPdf(state.pdfDirTextController.text);
    } catch (e) {
      error(e.toString());
      _end();
      return;
    }

    state.processEnum = state.processEnum.next() ?? state.processEnum;
    _end();
  }


  void order2Preview(String data) async{

  }

  void order2SelectRef(String data) async {

  }
}
