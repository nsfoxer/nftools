import 'package:get/get_state_manager/src/simple/get_controllers.dart';
import 'package:nftools/pages/settings/api/about_api.dart' as $api;
import 'package:nftools/pages/settings/state/about_state.dart';

class AboutController extends GetxController {
  final state = AboutState();

  @override
  void onReady() {
    _init();
    super.onReady();
  }

  void _init() async {
    state.version = await $api.version();
    state.newestVersion = await $api.newestVersion();
    state.record = await $api.getRecord();
    update();
  }

  // 比较当前版本号与最新版本号
  // 如果相等，则返回 0; 如果有更新版本，则返回 -1; 如果当前版本更大，则返回1
  int compareVersion() {
    if (state.version.isEmpty || state.newestVersion.isEmpty) {
      return 0;
    }
    return _compareVersions(state.version, state.newestVersion);
  }

  int _compareVersions(String version1, String version2) {
    List<int> v1 = _parseVersion(version1);
    List<int> v2 = _parseVersion(version2);

    for (int i = 0; i < 3; i++) {
      if (v1[i] > v2[i]) {
        return 1;
      } else if (v1[i] < v2[i]) {
        return -1;
      }
    }
    return 0;
  }

  List<int> _parseVersion(String version) {
    version = version.substring(1);
    List<String> parts = version.split('.');
    List<int> result = [];
    for (int i = 0; i < 3; i++) {
      if (i < parts.length) {
        result.add(int.tryParse(parts[i]) ?? 0);
      } else {
        result.add(0);
      }
    }
    return result;
  }

  void installNewest() async {
    if (state.isInstalling) {
      return;
    }
    state.isInstalling = true;
    update();
    try {
      await $api.installNewest();
    } finally {
      state.isInstalling = false;
      update();
    }
  }
}
