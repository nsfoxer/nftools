import 'package:nftools/api/api.dart';
import 'package:nftools/messages/common.pb.dart';

const String _service = "AutoStartService";
const String _getAutostart = "get_autostart";
const String _setAutostart = "set_autostart";

Future<bool> getAutoStart() async {
  final data = await sendRequest<EmptyMessage>(_service, _getAutostart, null);
  return BoolMessage.fromBuffer(data).value;
}

Future<void> setAutoStart(bool enable) async {
  await sendRequest(_service, _setAutostart, BoolMessage(value: enable));
}
