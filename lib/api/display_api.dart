// display service

import 'dart:ui';

import 'package:flex_color_scheme/flex_color_scheme.dart';
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
const String _getSystemColor = "get_system_color";

Future<DisplayMode> getCurrentMode() async {
  var data = await sendRequest<EmptyMessage>(_service2, _getCurrentMode, null);
  var result = DisplayMode.fromBuffer(data);
  return result;
}

Future<void> setMode(DisplayMode mode) async {
  await sendRequest(_service2, _setMode, mode);
}

Future<Color> getSystemColor() async {
  var data = await sendRequest<EmptyMessage>(_service2, _getSystemColor, null);
  var result = Uint32Message.fromBuffer(data);
  return Color(result.value).lighten(20);
}

Future<GetWallpaperRsp> getWallpaper() async {
  var data = await sendRequest<EmptyMessage>(_service2, _getWallpaper, null);
  var result = GetWallpaperRsp.fromBuffer(data);
  return result;
}
