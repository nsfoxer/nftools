import 'package:nftools/common/constants.dart';
import 'package:nftools/src/bindings/bindings.dart';

import '../../../api/api.dart';

const String _service = ServiceNameConstant.tarPdfService;
const String _handle = "handle";
const String _setConfig = "set_config";
const String _getConfig = "get_config";
const String _ocrCheck = "ocr_check";
const String _ocrResult = "get_result";
const String _exportResult = "export_result_and_rename_files";
const String _clearResult = "clear_result";


// start
Stream<TarPdfMsg> handle(String pdfDir) {
  var stream = sendRequestStream(_service, _handle, StringMsg(value: pdfDir));
  return stream.map((x) => TarPdfMsg.bincodeDeserialize(x));
}

Future<void> setConfig(String url, String apiKey, List<String> noRegex, String? pdfPasswd, String nameRule) async{
  if (pdfPasswd?.isEmpty ?? false) {
    pdfPasswd = null;
  }
  await sendRequest(_service, _setConfig, OcrConfigMsg(url: url, apiKey: apiKey, noRegex: noRegex, exportFileNameRule: nameRule, passwd: pdfPasswd));
}

Future<OcrConfigMsg> getConfig() async{
   final data = await sendEmptyRequest(_service, _getConfig);
   return OcrConfigMsg.bincodeDeserialize(data);
}

Future<void> ocrCheck() async{
  await sendEmptyRequest(_service, _ocrCheck);
}

Future<List<TarPdfResultMsg>> ocrResult() async {
  final data = await sendEmptyRequest(_service, _ocrResult);
  return TarPdfResultsMsg.bincodeDeserialize(data).datas;
}

Future<String> exportResult() async {
  final data = await sendEmptyRequest(_service, _exportResult);
  return StringMsg.bincodeDeserialize(data).value;
}

Future<void> clearResult() async {
  await sendEmptyRequest(_service, _clearResult);
}