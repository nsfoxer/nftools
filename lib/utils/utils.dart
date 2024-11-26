// 时间操作
import 'package:fluent_ui/fluent_ui.dart';
import 'package:go_router/go_router.dart';
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

// 确认弹出框
Future<bool> confirmDialog(
    BuildContext context, String title, String content) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => ContentDialog(
      title: Text(title),
      content: Text(content),
      actions: [
        FilledButton(
          child: const Text('确认'),
          onPressed: () {
            context.pop(true);
            // Delete file here
          },
        ),
        Button(
          child: const Text('取消'),
          onPressed: () => context.pop(false),
        ),
      ],
    ),
  );
  return result ?? false;
}
