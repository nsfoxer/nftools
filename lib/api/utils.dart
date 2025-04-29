
import '../common/constants.dart';
import '../src/bindings/bindings.dart';
import 'api.dart';

const String _service = ServiceNameConstant.utils;
const String _compressLocalPic = "compress_local_img";
const String _notify = "notify";
const String _networkStatus = "network_status";

// 压缩本地图片
Future<String> compressLocalFile(String localFile, int width, int height) async {
  var data = await sendRequest<CompressLocalPicMsg>
    (_service, _compressLocalPic, CompressLocalPicMsg(localFile: localFile, width: width, height: height));
  return StringMsg.bincodeDeserialize(data).value;
}

// 桌面通知
void notify(String msg) {
  sendRequest(_service, _notify, StringMsg(value: msg));
}

// 网络状态
Future<bool> networkStatus() async {
  var data = await sendRequest<EmptyMsg>
    (_service, _networkStatus, null);
  return BoolMsg.bincodeDeserialize(data).value;
}
