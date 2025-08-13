import 'package:file_picker/file_picker.dart';
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
    final url = await $api.getUrl();
    final urlKey = await $api.getUrlKey();
    if (url.isEmpty || urlKey.isEmpty) {
      warn("OCR服务未配置,请先配置!");
    }
    state.urlTextController.text = url;
    state.urlKeyTextController.text = urlKey;
  }

  void selectPdfDir() async {
    final path = await FilePicker.platform.getDirectoryPath();
    if (path == null) {
      return;
    }
    state.pdfDirTextController.text = path;
  }

  void start() async {
    final Stream<TarPdfMsg> stream;
    try {
      stream = $api.start(state.pdfDirTextController.text);
    } catch (e) {
      return;
    }

    state.processEnum = DisplayProcessEnum.processing;
    update();
    stream.listen((data) {
      state.sum = data.sum;
      state.current = data.now;
      state.result.add(data.currentFile);
      update();
    }, onDone: () {
      _end();
    }, onError: (e) {
      error(e.toString());
      state.processEnum = DisplayProcessEnum.start;
      state.result.clear();
      update();
    }, cancelOnError: true);
  }

  void _end() {
    state.processEnum = DisplayProcessEnum.end;
    update();
  }

  void reset() {
    state.reset();
    update();
  }

  void config() async {
    final url  = state.urlTextController.text;
    final urlKey = state.urlKeyTextController.text;
    await $api.setUrl(url);
    await $api.setUrlKey(urlKey);
    await $api.ocrCheck();
  }
}
