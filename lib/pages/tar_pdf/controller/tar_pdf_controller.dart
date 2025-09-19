import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:get/get_state_manager/src/simple/get_controllers.dart';
import 'package:nftools/pages/tar_pdf/state/tar_pdf_state.dart';
import 'package:nftools/src/bindings/signals/signals.dart';
import 'package:nftools/utils/extension.dart';
import 'package:nftools/utils/log.dart';
import 'package:nftools/utils/utils.dart';

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

  void selectExcelFile() async {
    final path = await FilePicker.platform.pickFiles(dialogTitle: "请选择excel文件", allowedExtensions: ["xlsx"], type: FileType.custom);
    if (path == null) {
      return;
    }
    state.renameFileController.text = path.files.first.path ?? "";
  }

  void reset() async {
    state.reset();
    // await $api.clearResult();
    await configReset();
    state.reset();
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

  // 下一步
  void next() {
    switch (state.processEnum) {
      case DisplayProcessEnum.order1:
        _nextOrder1();
        return;
      case DisplayProcessEnum.order2:
        debug("下一步 order2 不生效");
        return;
      case DisplayProcessEnum.order3:
        _nextOrder3();
      case DisplayProcessEnum.order4:
        // TODO: Handle this case.
        throw UnimplementedError();
      case DisplayProcessEnum.order5:
        _nextOrder5();
      case DisplayProcessEnum.order6:
        _nextOrder6();
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
      state.processEnum = state.processEnum.next() ?? state.processEnum;
    } finally {
      _end();
    }
  }

  void _nextOrder3() async {
    // 检查数据是否正确
    if (state.selectedTags.isEmpty) {
      warn("请选择标签");
      return;
    }
    state.refTemplateController.text = state.refTemplateController.text.trim();
    if (state.refTemplateController.text.isEmpty) {
      warn("请填写参考文件模板");
      return;
    }
    final result = await tryGetRefTemplateResult();
    if (result != null) {
      error("模板填写错误: $result");
      return;
    }

    // 开始处理
    final Stream<TarPdfMsg> stream = $api.handle(state.pdfFiles);
    state.processEnum = state.processEnum.next() ?? state.processEnum;
    update();
    stream.listen((data) {
      state.current = data.now;
      state.sum = data.sum;
      state.currentFile = data.currentFile;
      update();
    }, onDone: () {
      info("处理完成");
      _getResult();
    }, onError: (e) {
      error("处理失败: $e");
      state.processEnum = state.processEnum.pre() ?? state.processEnum;
      update();
    }, cancelOnError: true);
  }

  void _getResult() async {
    state.ocrResults = await $api.getOcrPdfData();
    state.processEnum = state.processEnum.next() ?? state.processEnum;
    update();
  }

  // 获取pdf封面
  Future<ImageProvider> order2Preview(String pdfPath) async {
    final imgBuf = await $api.getPdfCover(pdfPath);
    return MemoryImage(Uint8List.fromList(imgBuf));
  }

  // 选择参考文件
  void order2SelectRef(String pdfPath) async {
    state.processEnum = state.processEnum.next() ?? state.processEnum;
    _start();
    final ImageProvider img;
    try {
      img = await order2Preview(pdfPath);
      state.refImagePainterController.setImageProvider(img);
    } finally {
      _end();
    }
    
    // 识别坐标
    state.isRefOcrLoading = true;
    update();
    final data = await $api.setRefConfig(pdfPath);
    state.isRefOcrLoading = false;
    
    // 设置OCR结果数据
    state.refOcrDatas = await _convertOcrData(data, img);
    debug("参考文件本地识别结果:$data");

    update();
  }

  /// 转换文字识别结果为本地
  Future<List<OcrDataMsg>> _convertOcrData(List<OcrDataMsg> data, ImageProvider img) async  {
    final imgInfo = await getImageInfoFromProvider(img);
    final ratio = state.refImagePainterController.getImgRect().width / imgInfo.image.width;
    final picRect = state.refImagePainterController.getImgRect();
    return data.map((e) {
      return OcrDataMsg(id: e.id, text: e.text, location: _scaleLocation(e.location, ratio, Offset(picRect.left, picRect.top)));
    }).toList();
  }

  // 缩放原始坐标为显示坐标
  BoxPositionMsg _scaleLocation(BoxPositionMsg location, double ratio, Offset offset) {
    return BoxPositionMsg(
      x: location.x * ratio + offset.dx,
      y: location.y * ratio + offset.dy,
      width: location.width * ratio,
      height: location.height * ratio,
    );
  }

  // 添加或删除标签
  void selectTag(String string, bool isSelected) async {
    if (isSelected) {
      state.selectedTags.add(string);
    } else {
      state.selectedTags.remove(string);
    }
    update();
    await $api.setRefConfigTags(state.selectedTags.toList());
    tryGetRefTemplateResult();
  }

  /// 获取参考文件模板结果
  /// 如果失败,则返回错误信息
  Future<String?> tryGetRefTemplateResult() async {
    final template = state.refTemplateController.text;
    try {
      final result = await $api.setRefConfigTemplate(template);
      state.refTemplateResultValue = result;
      update();
    } catch (e) {
      return e.toString();
    }
    return null;
  }

  void _nextOrder5() async {
    state.processEnum = state.processEnum.next() ?? state.processEnum;
    update();
    final file = await $api.exportExcel();
    info("导出成功,文件路径:$file");

  }

  void _nextOrder6() async {
    if (state.renameFileController.text.isEmpty) {
      error("请设置文件");
      return;
    }

    final data = await $api.renameByExcel(state.renameFileController.text);
    state.renameFileResult = data;
    update();
  }
}
