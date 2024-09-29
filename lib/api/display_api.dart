// display service

import 'package:flutter/foundation.dart';
import 'package:nftools/api/api.dart';
import 'package:nftools/messages/common.pb.dart';
import 'package:nftools/messages/display.pb.dart';

const String _service = "DisplayLight";
const String _funcSupport = "get_all_devices";
const String _setLight = "set_light";

Future<List<DisplayInfo>> displaySupport() async {
  var data = await sendRequest<EmptyMessage>(_service, _funcSupport, null);
  var result = DisplayInfoResponse.fromBuffer(data);
  return result.infos;
}

Future<void> setLight(DisplayInfo info) async {
  await sendRequest(_service, _setLight, info);
}
