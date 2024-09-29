// display service

import 'package:nftools/api/api.dart';
import 'package:nftools/messages/display.pb.dart';

const String _service = "display_info";
const String _func_support = "support";

Future<bool> displaySupport() async {
  var data = await sendRequest<DisplaySupport>(_service, _func_support, null);
  var result = DisplaySupport.fromBuffer(data);
  return result.support;
}
