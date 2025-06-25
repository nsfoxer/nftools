import 'dart:io';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:logger/logger.dart';
import 'package:nftools/router/router.dart';

final _logger =Logger(printer: HybridPrinter(SimplePrinter(), error: PrettyPrinter(), fatal: PrettyPrinter()));

const Map<Level, (InfoBarSeverity, String)> _infoMap = {
  Level.info: (InfoBarSeverity.info, "通知"),
  Level.warning: (InfoBarSeverity.warning, "警告"),
  Level.error: (InfoBarSeverity.error, "错误"),
  Level.fatal: (InfoBarSeverity.error, "错误"),
};

/// info log
void debug(String message) {
  _print(message, Level.debug);
}
/// info log
void info(String message) {
  _print(message, Level.info);
}

/// warn log
void warn(String message) {
  _print(message, Level.warning);
}

/// error log
void error(String message) {
  _print(message, Level.error);
}

/// error log
void fatal(String message) {
  _print(message, Level.fatal);
}

void _print(String message, Level level) async {
  _logger.log(level, message);

  final context = MyRouterConfig.themeContext;
  final value = _infoMap[level];
  if (context == null || value == null) {
    return;
  }

  await displayInfoBar(context, duration: const Duration(seconds: 3),
      builder: (context, close) {
    return InfoBar(
      content: Text(message),
      severity: value.$1,
      title: Text(value.$2),
      isLong: message.length > 30,
      isIconVisible: true,
    );
  });
}
