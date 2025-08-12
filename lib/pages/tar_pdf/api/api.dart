import 'package:nftools/common/constants.dart';
import 'package:nftools/src/bindings/bindings.dart';

import '../../../api/api.dart';

const String _service = ServiceNameConstant.tarPdfService;
const String _start = "start";


// start
Stream<TarPdfMsg> start(String pdfDir) {
  var stream = sendRequestStream(_service, _start, StringMsg(value: pdfDir));
  return stream.map((x) => TarPdfMsg.bincodeDeserialize(x));
}
