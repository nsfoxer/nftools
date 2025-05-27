
import 'dart:typed_data';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:re_editor/re_editor.dart';

import '../../../src/bindings/bindings.dart';

class QrEncodeState {
  // 文本编辑控制器
  CodeLineEditingController codeLineEditingController = CodeLineEditingController();

  // 二维码图片数据
  Uint8List imageData = Uint8List(0);

  // 是否正在加载
  bool isLoading = false;

  // true: 数据转二维码 false: 二维码转数据
  bool isData2Qr = true;

  // 展示的图片数据
  String? imageDataForDecodeShow;

  // 图片焦点
  FocusNode imageFocus = FocusNode();

  // 二维码数据
  QrCodeDataMsgList? qRData;

  // 文件流数据
  List<int> fileData = [];

  // 选择的文件路径
  String? filePath;
}