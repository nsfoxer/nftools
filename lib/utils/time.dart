// 时间操作

Duration measureDelay(Function func) {
  var start = DateTime.timestamp();
  func();
  return DateTime.timestamp().difference(start);
}
