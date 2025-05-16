// 时间操作
import 'dart:convert';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:go_router/go_router.dart';

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

Color primaryColor(BuildContext context) {
  return FluentTheme.of(context).accentColor.normal;
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
    'SELECT', 'FROM', 'WHERE', 'GROUP BY', 'ORDER BY', 'HAVING', 'JOIN', 'LEFT JOIN', 'RIGHT JOIN', 'INNER JOIN', 'UNION'
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
        if (formatted.isNotEmpty &&!formatted.endsWith('\n')) {
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

