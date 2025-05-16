
import 'dart:typed_data';

import 'package:re_editor/re_editor.dart';

class QrEncodeState {
  CodeLineEditingController codeLineEditingController = CodeLineEditingController();
  Uint8List imageData = Uint8List(0);
  bool isLoading = false;

}