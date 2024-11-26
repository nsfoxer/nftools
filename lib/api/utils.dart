
import 'package:nftools/messages/common.pb.dart';
import 'package:nftools/messages/system_info.pb.dart';
import 'package:nftools/messages/utils.pb.dart';

import 'api.dart';

const String _service = "Utils";
const String _compressLocalPic = "compress_local_img";

// 压缩本地图片
Future<String> compressLocalFile(String localFile, int width, int height) async {
  var data = await sendRequest<CompressLocalPicMsg>
    (_service, _compressLocalPic, CompressLocalPicMsg(localFile: localFile, width: width, height: height));
  return StringMessage.fromBuffer(data).value;
}
