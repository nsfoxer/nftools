// display service

import 'dart:ui';

import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:nftools/api/api.dart';
import 'package:nftools/common/constants.dart';

import '../src/bindings/bindings.dart';

const String _service = ServiceNameConstant.displayLight;
const String _funcSupport = "get_all_devices";
const String _setLight = "set_light";

Future<List<DisplayInfoMsg>> displaySupport() async {
  var data = await sendRequest<EmptyMsg>(_service, _funcSupport, null);
  var result = DisplayInfoReqMsg.bincodeDeserialize(data);
  return result.infos;
}

Future<void> setLight(DisplayInfoMsg info) async {
  await sendRequest(_service, _setLight, info);
}

const String _service2 = ServiceNameConstant.displayMode;
const String _getCurrentMode = "get_current_mode";
const String _setMode = "set_mode";
const String _getWallpaper = "get_wallpaper";
const String _getSystemColor = "get_system_color";
const String _getSystemMode = "get_system_mode";
const String _setSystemMode = "set_system_mode";

Future<DisplayModeMsg> getCurrentMode() async {
  var data = await sendRequest<EmptyMsg>(_service2, _getCurrentMode, null);
  var result = DisplayModeMsg.bincodeDeserialize(data);
  return result;
}

Future<void> setMode(DisplayModeMsg mode) async {
  await sendRequest(_service2, _setMode, mode);
}

Future<Color> getSystemColor() async {
  var data = await sendRequest<EmptyMsg>(_service2, _getSystemColor, null);
  var result = UintFiveMsg.bincodeDeserialize(data);
  return Color(result.value).withAlpha(255).lighten();
}

Future<GetWallpaperRspMsg> getWallpaper() async {
  var data = await sendRequest<EmptyMsg>(_service2, _getWallpaper, null);
  var result = GetWallpaperRspMsg.bincodeDeserialize(data);
  return result;
}

Future<SystemModeMsg> getSystemMode() async {
  var data = await sendRequest<EmptyMsg>(_service2, _getSystemMode, null);
  var result = SystemModeMsg.bincodeDeserialize(data);
  return result;
}

Future<void> setSystemMode(bool enabled, bool keepScreen) async {
  final mode =  SystemModeMsg(enabled: enabled, keepScreen: keepScreen);
  await sendRequest(_service2, _setSystemMode, mode);
}

