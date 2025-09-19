import 'package:nftools/common/constants.dart';
import 'package:nftools/src/bindings/bindings.dart';

import '../../../api/api.dart';

const String _service = ServiceNameConstant.tarPdfService;
const String _handle = "handle";
const String _setConfig = "set_config";
const String _getConfig = "get_config";
const String _ocrCheck = "ocr_check";
const String _getOcrPdfData = "get_ocr_pdf_data";
const String _exportResult = "export_result_and_rename_files";
const String _clearResult = "clear_result";
const String _scanPdf = "scan_pdf";
const String _getPdfCover = "get_pdf_cover";
const String _setRefConfig = "set_ref_config";
const String _setRefConfigTags = "set_ref_config_tags";
const String _setRefConfigTemplate = "set_ref_config_template";


// start
Stream<TarPdfMsg> handle(List<String> pdfFiles) {
  var stream = sendRequestStream(_service, _handle, VecStringMsg(values: pdfFiles));
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

Future<TarPdfResultsMsg> getOcrPdfData() async {
  final data = await sendEmptyRequest(_service, _getOcrPdfData);
  return TarPdfResultsMsg.bincodeDeserialize(data);
}

Future<String> exportResult() async {
  final data = await sendEmptyRequest(_service, _exportResult);
  return StringMsg.bincodeDeserialize(data).value;
}

Future<void> clearResult() async {
  await sendEmptyRequest(_service, _clearResult);
}

// 获取指定文件夹下的所有pdf文件
Future<List<String>> listDirPdf(String pdfDir) async{
  final data = await sendRequest(_service, _scanPdf, StringMsg(value: pdfDir));
  return VecStringMsg.bincodeDeserialize(data).values;
}

// 获取pdf封面
Future<List<int>> getPdfCover(String pdfPath) async {
  final data = await sendRequest(_service, _getPdfCover, StringMsg(value: pdfPath));
  return DataMsg.bincodeDeserialize(data).value;
}

// 设置参考文件
Future<List<OcrDataMsg>> setRefConfig(String pdfPath) async {
  final data = await sendRequest(_service, _setRefConfig, StringMsg(value: pdfPath));
  return RefOcrDatasMsg.bincodeDeserialize(data).data;
}

// 设置参考文件标签
Future<void> setRefConfigTags(List<String> tags) async{
  await sendRequest(_service, _setRefConfigTags, VecStringMsg(values: tags));
}

// 设置参考文件模板
Future<String> setRefConfigTemplate(String template) async{
  final data = await sendRequest(_service, _setRefConfigTemplate, StringMsg(value: template));
  return StringMsg.bincodeDeserialize(data).value;
}
