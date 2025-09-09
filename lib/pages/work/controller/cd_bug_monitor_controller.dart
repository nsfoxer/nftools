import 'dart:async';

import 'package:dio/dio.dart';
import 'package:get/get_state_manager/src/simple/get_controllers.dart';
import 'package:nftools/pages/work/state/cd_bug_monitor_state.dart';
import 'package:nftools/utils/extension.dart';

import 'package:nftools/api/utils.dart' as $api;
import 'package:nftools/utils/log.dart';


class CdBugMonitorController extends GetxController with GetxUpdateMixin {
  CdBugsMonitorState state = CdBugsMonitorState();

  // 配置存储
  static final String _chanDaoUrl = "ChanDaoUrl";
  static final String _chanDaoCookie = "ChanDaoCookie";
  static final String _chanDaoEnable = "ChanDaoEnable";

  // 服务请求
  static Dio? _dio;
  // 数据匹配
  static final RegExp _regex = RegExp(
    r'我的BUG<\/div>\s*<div class="tile-amount">.*?(\d+).*?<\/div>',
    dotAll: true, // 使.可以匹配换行符
  );
  // 失败重试间隔
  static final _enhanceDelay = 60;
  // 正常重试间隔
  static final _normalDelay = _enhanceDelay * 10;

  // 定时器
  Timer? _timer;
  int _delay = _normalDelay;
  int _lastCount = 0;


  @override
  void onReady() {
    _getConfig();
    super.onReady();
  }

  // 获取配置
  void _getConfig() async {
    state.urlController.text = await getData(_chanDaoUrl);
    state.cookieController.text = await getData(_chanDaoCookie);
    final data = await $api.getData(_chanDaoEnable);
    state.enableMonitor = data == null ? false : bool.parse(data);
    update();

    if (state.enableMonitor) {
      _enableTimer();
    }
    refreshBugCount();
  }

  // 设置配置
  void setConfig() async {
    state.urlController.text = state.urlController.text.trimRight().replaceAll(RegExp(r'/$'), '');
    await $api.setData(_chanDaoUrl, state.urlController.text);
    await $api.setData(_chanDaoCookie, state.cookieController.text);
    await $api.setData(_chanDaoEnable, state.enableMonitor.toString());
    _dio = null;
  }

  // 获取配置
  Future<String> getData(String key) async {
    final data = await $api.getData(key);
    if (data == null) {
      return "";
    }
    return data;
  }

  // 更新bug数量
  Future<int?> refreshBugCount() async {
    final int count;
    try {
      count = await _getBugCount();
    } on Exception {
      warn("获取bug数量失败");
      state.count = null;
      update();
      return null;
    }
    _lastCount = state.count ?? 0;
    state.count = count;
    update();
    debug("bug数量: $count");
    return count;
  }

  bool _hasConfig() {
    return state.urlController.text.isNotEmpty && state.cookieController.text.isNotEmpty;
  }

  // 获取bug数量
  Future<int> _getBugCount() async {
    // 1. 获取网络配置
    if (_dio == null && !_setDio()) {
      throw Exception("请先配置网络和cookie");
    }
    // 2. 发送请求
    final rsp = await _dio!.get("/zentao/my/");
    if (rsp.statusCode != 200) {
      throw Exception("请求失败 请检查网络配置");
    }

    // 3. 获取body html
    if (rsp.data is! String) {
      throw Exception("请求失败");
    }
    final htmlBody = rsp.data as String;
    Match? match = _regex.firstMatch(htmlBody);
    if (match == null || match.groupCount < 1) {
      throw Exception("请求失败, 无法获取bug数量");
    }

    return int.parse(match.group(1)!);
  }
  /// 设置网络配置
  bool _setDio() {
    if (!_hasConfig()) {
      return false;
    }
    _dio = Dio(
      BaseOptions(
        baseUrl: state.urlController.text,
        headers: {
          "cookie": state.cookieController.text,
          "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/139.0.0.0 Safari/537.36",
        },
        validateStatus: (status) {
          if (status == null) {
            return false;
          }
          return status < 600;
        },
      ),
    );

    return true;
  }

  void switchMonitor() async {
    state.enableMonitor = !state.enableMonitor;
    await $api.setData(_chanDaoEnable, state.enableMonitor.toString());
    update();
    if (!state.enableMonitor) {
      _closeTimer();
    } else {
      _enableTimer();
    }
  }

  // 启用定时器
  void _enableTimer() {
    _closeTimer();
    _timer = Timer.periodic(Duration(seconds: _delay), (timer) async {
      int? count =  await refreshBugCount();

      // 获取bug数量失败
      if (count == null) {
        if (_updateDelay(_enhanceDelay)) {
          _enableTimer();
        }
        return;
      }

      // bug数量增加
      if (count > _lastCount) {
        debug("bug数量增加 $count");
        _notify(count);
        if (_updateDelay(_enhanceDelay)) {
          _enableTimer();
        }
      }

      // bug数量归0
      if (count == 0 && _updateDelay(_normalDelay)) {
          _enableTimer();
      }

    });
  }

  // 停用定时器
  void _closeTimer() {
    _timer?.cancel();
  }

  bool _updateDelay(int newValue) {
    if (newValue != _delay) {
      _delay = newValue;
      return true;
    }
    return false;
  }

  // 通知
  void _notify(int bugCount) {
    $api.notify("🔴🔴🔴当前存在 $bugCount个禅道Bug需要处理！");
  }

}
