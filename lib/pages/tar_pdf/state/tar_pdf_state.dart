import 'package:fluent_ui/fluent_ui.dart';

class TarPdfState {
  bool isProcess = false;
  DisplayProcessEnum processEnum = DisplayProcessEnum.start;

  int sum = 0;
  int current = 0;
  List<String> result = [];

  TextEditingController pdfDirTextController = TextEditingController();
  TextEditingController pdfPasswordTextController = TextEditingController();

  void reset() {
    isProcess = false;
    processEnum = DisplayProcessEnum.start;
    sum = 0;
    current = 0;
    result.clear();
    pdfDirTextController.clear();
    pdfPasswordTextController.clear();
  }
}

enum DisplayProcessEnum {
  start,
  processing,
  end
}