// 时间操作
import 'package:nftools/api/utils.dart' as $api;

Future<int> measureDelay(Future<void> Function() func) async {
  var watch = Stopwatch()..start();
  await func();
  watch.stop();
  return watch.elapsedMicroseconds;
}

// 本地图片压缩
Future<String> compressLocalPic(String localFile, int width, int height) async {
  return await $api.compressLocalFile(localFile, width, height);
}