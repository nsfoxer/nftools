// display service

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

const String _service2 = "DisplayMode";
const String _getCurrentMode = "get_current_mode";
const String _setMode = "set_mode";
const String _getWallpaper = "get_wallpaper";

Future<DisplayMode> getCurrentMode() async {
  var data = await sendRequest<EmptyMessage>(_service2, _getCurrentMode, null);
  var result = DisplayMode.fromBuffer(data);
  return result;
}

Future<void> setMode(DisplayMode mode) async {
  await sendRequest(_service2, _setMode, mode);
}

Future<GetWallpaperRsp> getWallpaper() async {
  var data = await sendRequest<EmptyMessage>(_service2, _getWallpaper, null);
  var result = GetWallpaperRsp.fromBuffer(data);
  return result;
}
