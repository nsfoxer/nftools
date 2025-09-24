import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:get/get_state_manager/src/simple/get_controllers.dart';
import 'package:nftools/pages/tar_pdf/state/tar_pdf_state.dart';
import 'package:nftools/src/bindings/signals/signals.dart';
import 'package:nftools/utils/extension.dart';
import 'package:nftools/utils/log.dart';
import 'package:nftools/utils/utils.dart';
import 'package:pasteboard/pasteboard.dart';

import '../api/api.dart' as $api;

class TarPdfController extends GetxController with GetxUpdateMixin {
  TarPdfState state = TarPdfState();

  // 文本框渲染原始数据
  List<OcrDataMsg> _originalOcrDatas = [];


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
    _originalOcrDatas.clear();
    await configReset();
    await $api.reset();
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
  }

  Future<bool> setConfig() async {
    final url = state.urlTextController.text;
    final urlKey = state.apiKeyTextController.text;
    final passwd = state.pdfPasswordTextController.text;

    if (url.isEmpty || urlKey.isEmpty) {
      error("请补全配置");
      return false;
    }

    state.isConfigLoading = true;
    update();

    try {
      await $api.setConfig(url, urlKey, passwd);
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

  // 下一步
  void next(BuildContext context) async {
    switch (state.processEnum) {
      case DisplayProcessEnum.order1:
        _nextOrder1();
        return;
      case DisplayProcessEnum.order2:
        debug("下一步 order2 不生效");
        return;
      case DisplayProcessEnum.order3:
        if ((await _nextOrder3Check())) {
          _nextOrder3(context);
        }
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

  // next3 check
  Future<bool> _nextOrder3Check() async {
    // 检查数据是否正确
    if (state.selectedTags.isEmpty) {
      warn("请选择标签");
      return false;
    }
    state.refTemplateController.text = state.refTemplateController.text.trim();
    if (state.refTemplateController.text.isEmpty) {
      warn("请填写参考文件模板");
      return false;
    }
    final result = await tryGetRefTemplateResult();
    if (result != null) {
      error("模板填写错误: $result");
      return false;
    }

    return true;
  }

  void _nextOrder3(BuildContext context) async {
    if (!context.mounted) {
      return;
    }
    final enable = await confirmDialog(context, "是否启用相似性检查", "启用后将根据参考文件进行相似性对比,跳过不相似的pdf文件");

    // 开始处理
    final Stream<TarPdfMsg> stream = $api.handle(state.pdfFiles, enable);
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
      await state.refImagePainterController.setImageProvider(img);
    } finally {
      _end();
    }
    
    // 识别坐标
    state.isRefOcrLoading = true;
    update();
    _originalOcrDatas = await $api.setRefConfig(pdfPath);
    state.isRefOcrLoading = false;
    state.refOcrDatas = _originalOcrDatas;
    update();
  }

  /// 转换文字识别结果为本地
  void mapRefOcrData2LocalData() {
    final picRect = state.refImagePainterController.displayRect;
    final imgSize = state.refImagePainterController.imgSize;
    final ratio = picRect.width / imgSize.width;
    state.refOcrDatas = _originalOcrDatas.map((e) {
      return OcrDataMsg(id: e.id, text: e.text, location: _scaleLocation(e.location, ratio, Offset(picRect.left, picRect.top)));
    }).toList();
    update(["TarPdfPage-Order3-TextRect"]);
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
      state.refTemplateResultErrorMsg = "";
      update();
    } catch (e) {
      debug("模板填写错误: $e");
      state.refTemplateResultValue = "";
      state.refTemplateResultErrorMsg = e.toString();
      update();
      return e.toString();
    }
    return null;
  }

  void _nextOrder5() async {
    state.processEnum = state.processEnum.next() ?? state.processEnum;
    update();
    final file = await $api.exportExcel();
    info("导出成功,文件路径:$file");
    state.exportFilePath = file;
    update();
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

  void copyFilePath() {
    Pasteboard.writeText(state.exportFilePath);
    info("已复制文件路径:${state.exportFilePath}");
  }
}
