import 'package:nftools/src/bindings/bindings.dart';

import '../common/constants.dart';
import '../utils/log.dart';
import 'api.dart';

const String _service = ServiceNameConstant.imageSplitService;
const String _createImage = "create_image";
const String _clear = "clear";
const String _handleImage = "handle_image";

/// 创建图像
Future<void> createImage(String imgFile) async {
  await sendRequest<StringMsg>(_service, _createImage, StringMsg(value: imgFile));
}

/// 清除内存
Future<void> clear() async {
  await sendRequest<EmptyMsg>(_service, _clear, null);
}

/// 处理图像
Future<String> handleImage(ImageSplitReqMsg req) async {
  debug("handleImage: ${req}");
  final data = await sendRequest(_service, _handleImage, req);
  return StringMsg.bincodeDeserialize(data).value;
}