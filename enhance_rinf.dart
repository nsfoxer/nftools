// 排除该文件的代码分析
// ignore_for_file: type=lint
import 'dart:io';

// 正则表达式用于匹配 @immutable 标记的类定义
final RegExp immutableClassRegex = RegExp(
  r'(@immutable\s*class\s+(\w+))',
  multiLine: true,
  dotAll: true,
);

// 正则表达式用于匹配 mixin 定义
final RegExp mixinRegex = RegExp(
  r'with\s+([\w, ]+)',
  multiLine: true,
  dotAll: true,
);

// 处理单个文件
void processFile(File file) {
  final content = file.readAsStringSync();
  final matches = immutableClassRegex.allMatches(content);
  String newContent = content;

  for (final match in matches) {
    final endIndex = match.end;

    // 查找类定义结束的位置
    int classEndIndex = endIndex;
    int braceCount = 1;
    while (braceCount > 0 && classEndIndex < content.length) {
      final char = content[classEndIndex];
      if (char == '{') braceCount++;
      if (char == '}') braceCount--;
      classEndIndex++;
    }

    // 检查类是否已经有 with 语句
    final classBody = content.substring(endIndex, classEndIndex - 1);
    final mixinMatch = mixinRegex.firstMatch(classBody);
    if (mixinMatch != null) {
      final currentMixins = mixinMatch.group(1)!;
      if (!currentMixins.contains('ApiSerializable')) {
        final newMixins = '$currentMixins, ApiSerializable';
        newContent = newContent.replaceRange(
          endIndex + mixinMatch.start,
          endIndex + mixinMatch.end,
          'with $newMixins',
        );
      }
    } else {
      // 若没有 with 语句，添加 with ApiSerializable
      final insertIndex = content.indexOf('{', endIndex);
      newContent = newContent.replaceRange(
        insertIndex,
        insertIndex,
        ' with ApiSerializable',
      );
    }
  }

  if (newContent != content) {
    file.writeAsStringSync(newContent);
    print('Updated ${file.path}');
  }
}

// 处理文件夹
void processDirectory(Directory directory) {
  for (final entity in directory.listSync(recursive: false)) {
    if (entity is File && entity.path.endsWith('.dart')) {
      processFile(entity);
    }
  }
}

void addImport(File signalFile) {
  // 查找第一个import开头的行，并在之后新增一行 abc
  final content = signalFile.readAsStringSync();
  final lines = content.split('\n');

  for (int i = 0; i < lines.length; i++) {
    if (lines[i].trim().startsWith('import')) {
      // 在找到的import行后插入新行
      lines.insert(i + 1, r"import '../../../api/api.dart';");
      break;
    }
  }

  // 将修改后的内容写回文件
  final newContent = lines.join('\n');
  signalFile.writeAsStringSync(newContent);
}


void main() {
  final targetDir = Directory('lib/src/bindings/signals');
  if (targetDir.existsSync()) {
    processDirectory(targetDir);
  } else {
    print('Directory not found: ${targetDir.path}');
  }

  final signalFile = File('lib/src/bindings/signals/signals.dart');
  if (signalFile.existsSync()) {
    print("add import ${signalFile}");
    addImport(signalFile);
  }
}

