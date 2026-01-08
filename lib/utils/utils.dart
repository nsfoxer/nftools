// 时间操作
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:meta/meta.dart';
import 'package:nftools/utils/log.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

Future<int> measureDelay(Future<void> Function() func) async {
  var watch = Stopwatch()..start();
  await func();
  watch.stop();
  return watch.elapsedMicroseconds;
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

// 是否为黑色模式
bool isDark(BuildContext context) {
  return View.of(context).platformDispatcher.platformBrightness.isDark;
}

// 主题主色
Color primaryColor(BuildContext? context) {
  return context == null ? Colors.orange: FluentTheme.of(context).accentColor.normal;
}

const JsonDecoder _jsonDecoder = JsonDecoder();
const JsonEncoder _jsonPrettyEncoder = JsonEncoder.withIndent('  ');

String formatJson(String json) {
  final data = _jsonDecoder.convert(json);
  return _jsonPrettyEncoder.convert(data);
}

String formatSql(String sql) {
  // 定义 SQL 关键字，用于换行和缩进
  final keywords = [
    'SELECT',
    'FROM',
    'WHERE',
    'GROUP BY',
    'ORDER BY',
    'HAVING',
    'JOIN',
    'LEFT JOIN',
    'RIGHT JOIN',
    'INNER JOIN',
    'UNION'
  ];

  // 移除 SQL 语句中的注释
  sql = _removeComments(sql);

  List<String> words = sql.split(RegExp(r'\s+'));
  List<String> processedWords = [];

  // 处理以;结尾的单词
  for (String word in words) {
    if (word.endsWith(';')) {
      processedWords.add(word.substring(0, word.length - 1));
      processedWords.add(';');
    } else {
      processedWords.add(word);
    }
  }
  words = processedWords;

  // 使用正则表达式按一个或多个空白字符分割 SQL 语句
  String formatted = '';
  int indentLevel = 0;
  int i = 0;

  while (i < words.length) {
    bool isKeywordMatch = false;
    for (String keyword in keywords) {
      List<String> keywordParts = keyword.split(' ');
      if (i + keywordParts.length <= words.length) {
        bool match = true;
        for (int j = 0; j < keywordParts.length; j++) {
          if (words[i + j].toUpperCase() != keywordParts[j]) {
            match = false;
            break;
          }
        }
        if (match) {
          // 如果是关键字，换行并根据缩进级别添加缩进
          formatted += '\n${'    ' * indentLevel}$keyword';
          if (keyword == 'SELECT') {
            indentLevel++;
          } else if (keyword == 'FROM') {
            indentLevel--;
          }
          i += keywordParts.length;
          isKeywordMatch = true;
          break;
        }
      }
    }

    if (!isKeywordMatch) {
      String word = words[i];
      if (word == ';') {
        // 遇到分号，换行并结束语句
        formatted += '$word\n';
      } else {
        // 普通单词，添加空格连接
        if (formatted.isNotEmpty && !formatted.endsWith('\n')) {
          formatted += ' ';
        }
        formatted += word;
      }
      i++;
    }
  }

  return formatted.trim();
}

String _removeComments(String sql) {
  // 移除单行注释
  sql = sql.replaceAll(RegExp(r'--.*'), '');
  // 移除多行注释
  sql = sql.replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '');
  return sql;
}

/// 生成临时文件路径
Future<String> getTempFilePath({String? fileExtension}) async {
  final directory = await getTemporaryDirectory();
  final path = join(directory.path,
      '${DateTime.now().millisecondsSinceEpoch}.${fileExtension?? 'tmp'}');
  // 时间戳生成文件名
  return path;
}

/// 保存数据到临时文件
Future<File> saveBytesToTempFile(List<int> bytes,
    {String? fileExtension}) async {
  final path = await getTempFilePath(fileExtension: fileExtension);
  // 时间戳生成文件名
  final file = File(path);
  return await file.writeAsBytes(bytes);
}

/// 增强版节流器
class NFDebounce {
  static final Map<String, TimerInfo> _operations = {};

  /// 节流增强版: 添加最大计时器, 超过最大时间后, 即使仍被节流,仍旧触发执行
  /// [tag] 标签
  /// [duration] 节流时间
  /// [maxDuration] 最大时间, 超过后, 即使仍被节流, 也会触发执行
  /// [onExecute] 执行函数
  static void debounce(
    String tag,
    Duration duration,
    Duration maxDuration,
    VoidCallback onExecute,
  ) {
    // 参数验证
    if (duration <= Duration.zero) {
      warn("duration[$duration] 必须大于零, 直接执行");
      onExecute();
      return;
    }

    if (maxDuration <= duration) {
      warn("maxDuration[$maxDuration] 必须大于 duration[$duration], 使用 duration");
      maxDuration = duration * 2; // 默认设为 duration 的两倍
    }

    // 移除之前的定时器
    final previous = _operations[tag];
    previous?.debounceTimer.cancel();

    // 创建新的计时器
    final Timer debounceTimer = Timer(duration, () {
      // 防抖定时器触发时，取消最大定时器
      _operations[tag]?.maxTimer.cancel();
      _operations.remove(tag);
      onExecute();
    });

    // 创建新的最大定时器
    final Timer maxTimer = previous?.maxTimer ??
        Timer(maxDuration, () {
          // 最大定时器触发时，取消防抖定时器
          _operations[tag]?.debounceTimer.cancel();
          _operations.remove(tag);
          onExecute();
        });

    // 存储新的定时器
    _operations[tag] = TimerInfo(debounceTimer, maxTimer);
  }

  // 清理所有定时器
  static void cancelAll() {
    _operations.forEach((_, info) {
      info.debounceTimer.cancel();
      info.maxTimer.cancel();
    });
    _operations.clear();
  }
}

@Immutable()
class TimerInfo {
  final Timer debounceTimer;
  final Timer maxTimer;

  TimerInfo(this.debounceTimer, this.maxTimer);
}

/// 获取image信息
Future<ImageInfo> getImageInfoFromProvider(ImageProvider provider) async {
  final ImageStream stream = provider.resolve(ImageConfiguration.empty);

  // 使用Completer等待图像加载完成
  final Completer<ImageInfo> completer = Completer<ImageInfo>();
  final ImageStreamListener listener = ImageStreamListener(
    (ImageInfo imageInfo, bool synchronousCall) {
      completer.complete(imageInfo);
    },
    onError: (dynamic exception, StackTrace? stackTrace) {
      completer.completeError(exception, stackTrace);
    },
  );

  stream.addListener(listener);

  try {
    return await completer.future;
  } finally {
    stream.removeListener(listener);
  }
}

/// 判断rect是否太小
bool isRectTooSmall(Rect rect, double minSize) {
  if (rect.isEmpty) {
    return true;
  }
  final width = rect.width;
  final height = rect.height;
  return width < minSize || height < minSize;
}


/// 简单的字符串加密解密工具
final int _key = 11;

/// 加密字符串
String encrypt(String text) {
  StringBuffer encrypted = StringBuffer();

  for (int i = 0; i < text.length; i++) {
    int code = text.codeUnitAt(i);

    // 处理大写字母
    if (code >= 65 && code <= 90) {
      code = (code - 65 + _key) % 26 + 65;
    }
    // 处理小写字母
    else if (code >= 97 && code <= 122) {
      code = (code - 97 + _key) % 26 + 97;
    }
    // 数字
    else if (code >= 48 && code <= 57) {
      code = (code - 48 + _key) % 10 + 48;
    }
    // 其他字符不加密

    encrypted.writeCharCode(code);
  }

  return encrypted.toString();
}

/// 解密字符串
String decrypt(String encryptedText) {
  StringBuffer decrypted = StringBuffer();

  for (int i = 0; i < encryptedText.length; i++) {
    int code = encryptedText.codeUnitAt(i);

    // 处理大写字母
    if (code >= 65 && code <= 90) {
      code = (code - 65 - _key + 26) % 26 + 65;
    }
    // 处理小写字母
    else if (code >= 97 && code <= 122) {
      code = (code - 97 - _key + 26) % 26 + 97;
    }
    // 数字
    else if (code >= 48 && code <= 57) {
      code = (code - 48 - _key + 10) % 10 + 48;
    }
    // 其他字符不解密

    decrypted.writeCharCode(code);
  }

  return decrypted.toString();
}