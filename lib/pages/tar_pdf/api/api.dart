import 'package:nftools/common/constants.dart';
import 'package:nftools/src/bindings/bindings.dart';

import '../../../api/api.dart';

const String _service = ServiceNameConstant.tarPdfService;
const String _start = "start";
const String _getUrl = "get_url";
const String _getUrlKey = "get_url_key";
const String _setUrl = "set_url";
const String _setUrlKey = "set_url_key";
const String _setPdfPassword = "set_password";
const String _ocrCheck = "ocr_check";
const String _ocrResult = "get_result";


// start
Stream<TarPdfMsg> start(String pdfDir) {
  var stream = sendRequestStream(_service, _start, StringMsg(value: pdfDir));
  return stream.map((x) => TarPdfMsg.bincodeDeserialize(x));
}

Future<String> getUrl() async{
   final result = await sendEmptyRequest(_service, _getUrl);
   return StringMsg.bincodeDeserialize(result).value;
}

Future<String> getUrlKey() async{
   final result = await sendEmptyRequest(_service, _getUrlKey);
   return StringMsg.bincodeDeserialize(result).value;
}

Future<void> setUrl(String url) async{
   await sendRequest(_service, _setUrl, StringMsg(value: url));
}

Future<void> setUrlKey(String urlKey) async{
   await sendRequest(_service, _setUrlKey, StringMsg(value: urlKey));
}

Future<void> setPdfPassword(String password) async {
  await sendRequest(_service, _setPdfPassword, StringMsg(value: password));
}

Future<void> ocrCheck() async{
  await sendEmptyRequest(_service, _ocrCheck);
}

Future<List<TarPdfResultMsg>> ocrResult() async {
  final data = await sendEmptyRequest(_service, _ocrResult);
  return TarPdfResultsMsg.bincodeDeserialize(data).datas;
}