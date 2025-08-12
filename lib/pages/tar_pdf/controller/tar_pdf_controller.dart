import 'package:file_picker/file_picker.dart';
import 'package:get/get_state_manager/src/simple/get_controllers.dart';
import 'package:nftools/pages/tar_pdf/state/tar_pdf_state.dart';
import 'package:nftools/src/bindings/signals/signals.dart';
import 'package:nftools/utils/extension.dart';
import 'package:nftools/utils/log.dart';

import '../api/api.dart' as $api;

class TarPdfController extends GetxController with GetxUpdateMixin {
  TarPdfState state = TarPdfState();

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
}
