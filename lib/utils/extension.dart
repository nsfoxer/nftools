
import 'package:get/get_state_manager/src/simple/get_controllers.dart';
import 'package:nftools/utils/utils.dart';

mixin GetxUpdateMixin on GetxController {

  @override
  void update([List<Object>? ids, bool condition = true]) {
    // 默认参数
    if (ids == null && condition) {
      // 节流
      NFDebounce.debounce(runtimeType.toString(), Duration(milliseconds: 80), Duration(milliseconds: 100), () {
        super.update(ids, condition);
      });
    } else {
      super.update(ids, condition);
    }
  }
}