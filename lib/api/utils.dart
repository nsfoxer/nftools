import 'dart:typed_data';

import '../common/constants.dart';
import '../src/bindings/bindings.dart';
import 'api.dart';

const String _service = ServiceNameConstant.utils;
const String _compressLocalPic = "compress_local_img";
const String _notify = "notify";
const String _networkStatus = "network_status";
const String _genTextQrCode = "gen_text_qr_code";
const String _genFileQrCode = "gen_file_qr_code";
const String _detectQrCode = "detect_qr_code";
const String _detectFileQrCode = "detect_file_qr_code";
const String _spiltImage = "split_img";
const String _setData = "set_data";
const String _getData = "get_data";

// 压缩本地图片
Future<CompressLocalPicRspMsg> compressLocalFile(
    String localFile, int width, int height) async {
  var data = await sendRequest<CompressLocalPicMsg>(_service, _compressLocalPic,
      CompressLocalPicMsg(localFile: localFile, width: width, height: height));
  return CompressLocalPicRspMsg.bincodeDeserialize(data);
}

// 桌面通知
void notify(String msg) {
  sendRequest(_service, _notify, StringMsg(value: msg));
}

// 网络状态
Future<bool> networkStatus() async {
  var data = await sendRequest<EmptyMsg>(_service, _networkStatus, null);
  return BoolMsg.bincodeDeserialize(data).value;
}

// 生成文本二维码
Future<Uint8List> genTextQrCode(String text) async {
  final data = await sendRequest<StringMsg>(
      _service, _genTextQrCode, StringMsg(value: text));
  return Uint8List.fromList(DataMsg.bincodeDeserialize(data).value);
}

// 生成文件二维码
Future<Uint8List> genFileQrCode(String text) async {
  final data = await sendRequest<StringMsg>(
      _service, _genFileQrCode, StringMsg(value: text));
  return Uint8List.fromList(DataMsg.bincodeDeserialize(data).value);
}

// 探测图片二维码
Future<QrCodeDataMsgList> detectQrCode(Uint8List data) async {
  final result = await sendRequest<DataMsg>(
      _service, _detectQrCode, DataMsg(value: data.toList()));
  return QrCodeDataMsgList.bincodeDeserialize(result);
}

// 探测文件二维码
Future<QrCodeDataMsgList> detectFileQrCode(String path) async {
  final result = await sendRequest<StringMsg>(
      _service, _detectFileQrCode, StringMsg(value: path));
  return QrCodeDataMsgList.bincodeDeserialize(result);
}

/// 图片切割
Future<Uint8List> splitImage(SplitImageMsg imgMsg) async {
  final result = await sendRequest(_service, _spiltImage, imgMsg);
  return Uint8List.fromList(DataMsg.bincodeDeserialize(result).value);
}

/// 存储数据
Future<void> setData(String key, String value) async {
  await sendRequest(_service, _setData, PairStringMsg(key: key, value: value));
}

/// 获取数据
Future<String> getData(String key) async {
  final result = await sendRequest(_service, _getData, StringMsg(value: key));
  return StringMsg.bincodeDeserialize(result).value;
}
