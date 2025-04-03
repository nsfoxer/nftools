
import 'package:nftools/messages/common.pb.dart';
import 'package:nftools/messages/utils.pb.dart';

import '../common/constants.dart';
import 'api.dart';

const String _service = ServiceNameConstant.utils;
const String _compressLocalPic = "compress_local_img";
const String _notify = "notify";
const String _networkStatus = "network_status";

// 压缩本地图片
Future<String> compressLocalFile(String localFile, int width, int height) async {
  var data = await sendRequest<CompressLocalPicMsg>
    (_service, _compressLocalPic, CompressLocalPicMsg(localFile: localFile, width: width, height: height));
  return StringMessage.fromBuffer(data).value;
}

// 桌面通知
void notify(String msg) {
  sendRequest(_service, _notify, StringMessage(value: msg));
}

// 网络状态
Future<bool> networkStatus() async {
  var data = await sendRequest<EmptyMessage>
    (_service, _networkStatus, null);
  return BoolMessage.fromBuffer(data).value;
}
