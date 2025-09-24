
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

// 扩展方法：为List添加安全访问功能
extension SafeListAccess<T> on List<T> {
  // 获取指定索引的元素，越界则返回null
  T? safeGet(int index) {
    // 检查索引是否在有效范围内
    if (index >= 0 && index < length) {
      return this[index];
    }
    return null;
  }
}