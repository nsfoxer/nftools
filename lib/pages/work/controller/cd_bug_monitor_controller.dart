import 'dart:async';
import 'dart:convert';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:crypto/crypto.dart';

import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:get/get.dart';
import 'package:nftools/pages/work/state/cd_bug_monitor_state.dart';
import 'package:nftools/utils/extension.dart';

import 'package:nftools/api/utils.dart' as $api;
import 'package:nftools/utils/log.dart';

import '../../../controller/router_controller.dart';


class CdBugMonitorController extends GetxController with GetxUpdateMixin {
  CdBugsMonitorState state = CdBugsMonitorState();

  Rx<DateTime> updateTime = DateTime.now().obs;

  // router
  final RouterController _routerController = Get.find<RouterController>();

  // 配置存储
  static final String _chanDaoUrl = "ChanDaoUrl";
  static final String _chanDaoUser = "ChanDaoUser";
  static final String _chanDaoPasswd = "ChanDaoPasswd";
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
    state.userController.text = await getData(_chanDaoUser);
    state.passwdController.text = await getData(_chanDaoPasswd);
    final data = await $api.getData(_chanDaoEnable);
    state.enableMonitor = data == null ? false : bool.parse(data);
    update();

    if (state.enableMonitor) {
      _enableTimer();
    }
    refreshBugCount(true);
  }

  // 设置配置
  void setConfig() async {
    state.urlController.text = state.urlController.text.trimRight().replaceAll(RegExp(r'/$'), '');
    await $api.setData(_chanDaoUrl, state.urlController.text);
    await $api.setData(_chanDaoUser, state.userController.text);
    await $api.setData(_chanDaoPasswd, state.passwdController.text);
    await $api.setData(_chanDaoEnable, state.enableMonitor.toString());
    _dio = null;
    refreshBugCount(true);
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
  Future<int?> refreshBugCount(bool notify) async {
    updateTime.value = DateTime.now();
    final int count;
    try {
      count = await _getBugCount();
    } on Exception catch (e) {
      warn("获取bug数量失败: $e");
      if (notify) {
        $api.notify("🔔 禅道bug获取失败: $e");
      }
      state.count = null;
      update();
      return null;
    }
    _lastCount = state.count ?? 0;
    state.count = count;
    update();

   !_routerController.setInfoBadge("/cdBugMonitor", count > 0 ? count.toString() : null);
    return count;
  }

  bool _hasConfig() {
    return state.urlController.text.isNotEmpty
        && state.userController.text.isNotEmpty
        && state.passwdController.text.isNotEmpty;
  }

  // 获取bug数量
  Future<int> _getBugCount() async {
    // 1. 获取body
    String htmlBody = await _getMyBody();

    // 2. 是否需要刷新
    if (_needRefreshCookie(htmlBody)) {
      await _refreshCookie();
      htmlBody = await _getMyBody();
      info("已刷新禅道cookie");
    }

    Match? match = _regex.firstMatch(htmlBody);
    if (match == null || match.groupCount < 1) {
      throw Exception("请求失败, 无法获取bug数量");
    }

    return int.parse(match.group(1)!);
  }

  Future<String> _getMyBody() async {
    // 1. 获取网络配置
    if (_dio == null && !_setDio()) {
      throw Exception("请先配置网络");
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
    return rsp.data as String;
  }

  bool _needRefreshCookie(String htmlBody) {
    return htmlBody.contains("<script>self.location='/zentao/user-login");
  }

  Future<void> _refreshCookie() async {
    // 1. 获取rand和临时cookie
    assert(_dio != null);
    final rsp = await _dio!.get("/zentao/user-refreshRandom.html");
    if (rsp.statusCode != 200) {
      throw Exception("请求失败 请检查网络配置");
    }
    final rand = rsp.data as String;

    // 2. 发送请求,获取cookie
    final rsp2 = await _dio!.post("/zentao/user-login.html",
        options: Options(
          contentType: "application/x-www-form-urlencoded; charset=UTF-8",
          headers: {
            "X-Requested-With": "XMLHttpRequest",
          },
        ),
        data: {
      "account": state.userController.text,
      "password": _encodePassword(rand, state.passwdController.text),
      'passwordStrength': '2',
      'referer': '/zentao/',
      "verifyRand": rand,
      'keepLogin': '1',
      'captcha': '',
    });
    if (rsp2.statusCode != 200) {
      throw Exception("请求失败 请检查网络配置");
    }
    if (!_loginSuccess(rsp2.data)) {
      throw Exception("登录失败 请检查用户名或密码");
    }
  }

  String _encodePassword(String rand, String password) {
     final str1 = md5.convert(utf8.encode(password)).toString() + rand;
     return md5.convert(utf8.encode(str1)).toString();
  }

  bool _loginSuccess(dynamic rsp) {
    if (rsp is! String) {
      return false;
    }
    try {
      final data = json.decode(rsp)["result"];
      return data == "success";
    } catch (e) {
      return false;
    }
  }

  /// 设置网络配置
  bool _setDio() {
    if (!_hasConfig()) {
      return false;
    }
    debug("dio被设置");
    _dio = Dio(
      BaseOptions(
        baseUrl: state.urlController.text,
        headers: {
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
    _dio!.interceptors.add(CookieManager(CookieJar()));

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
      int? count =  await refreshBugCount(false);

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
    $api.notify("🔔🔔🔔当前存在 $bugCount个禅道Bug需要处理！");
  }

}
