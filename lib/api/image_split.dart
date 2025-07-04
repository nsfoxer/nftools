import 'dart:typed_data';

import 'package:nftools/src/bindings/bindings.dart';

import '../common/constants.dart';
import 'api.dart';

const String _service = ServiceNameConstant.imageSplitService;
const String _createImage = "create_image";
const String _clear = "clear";
const String _handleImage = "handle_image";
const String _previewImage = "preview_image";

/// 创建图像
Future<void> createImage(Uint8List imgData) async {
  await sendRequest(_service, _createImage, DataMsg(value: imgData));
}

/// 清除内存
Future<void> clear() async {
  await sendRequest<EmptyMsg>(_service, _clear, null);
}

/// 处理图像
Future<Uint8List> handleImage(ImageSplitReqMsg req) async {
  final data = await sendRequest(_service, _handleImage, req);
  return Uint8List.fromList(DataMsg.bincodeDeserialize(data).value);
}

/// 完成图像
Future<Uint8List> previewImage() async {
  final data = await sendRequest<EmptyMsg>(_service, _previewImage, null);
  return Uint8List.fromList(DataMsg.bincodeDeserialize(data).value);
}