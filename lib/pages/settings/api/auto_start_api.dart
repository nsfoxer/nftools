import 'package:nftools/api/api.dart';

import '../../../src/bindings/bindings.dart';

const String _service = "AutoStartService";
const String _getAutostart = "get_autostart";
const String _setAutostart = "set_autostart";

Future<bool> getAutoStart() async {
  final data = await sendRequest<EmptyMsg>(_service, _getAutostart, null);
  return BoolMsg.bincodeDeserialize(data).value;
}

Future<void> setAutoStart(bool enable) async {
  await sendRequest(_service, _setAutostart, BoolMsg(value: enable));
}
