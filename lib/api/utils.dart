import 'dart:typed_data';

import '../common/constants.dart';
import '../src/bindings/bindings.dart';
import '../utils/log.dart';
import 'api.dart';

const String _service = ServiceNameConstant.utils;
const String _notify = "notify";
const String _networkStatus = "network_status";
const String _genTextQrCode = "gen_text_qr_code";
const String _genFileQrCode = "gen_file_qr_code";
const String _setData = "set_data";
const String _getData = "get_data";


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



/// 存储数据
Future<void> setData(String key, String value) async {
  await sendRequest(_service, _setData, PairStringMsg(key: key, value: value));
}

/// 获取数据
Future<String?> getData(String key) async {
  try {
    final result = await sendRequest(_service, _getData, StringMsg(value: key));
    return StringMsg.bincodeDeserialize(result).value;
  } catch (e) {
    debug("获取存储数据失败:$key -- $e");
    return null;
  }
}
