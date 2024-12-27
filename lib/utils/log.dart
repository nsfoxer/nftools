import 'package:fluent_ui/fluent_ui.dart';
import 'package:nftools/router/router.dart';

const Map<InfoBarSeverity, String> _infoNameMap = {
  InfoBarSeverity.info: "通知",
  InfoBarSeverity.success: "成功",
  InfoBarSeverity.warning: "警告",
  InfoBarSeverity.error: "错误",
};

/// info log
void info(String message) {
  _print(message, InfoBarSeverity.info);
}

/// warn log
void warn(String message) {
  _print(message, InfoBarSeverity.warning);
}

/// error log
void error(String message) {
  _print(message, InfoBarSeverity.error);
}

void _print(String message, InfoBarSeverity serverity) async {
  debugPrint("${serverity.name}: $message");
  final context = MyRouterConfig.themeContext;
  if (context == null) {
    return;
  }
  await displayInfoBar(context, duration: const Duration(seconds: 3),
      builder: (context, close) {
    return InfoBar(
      content: Text(message),
      severity: serverity,
      title: Text(_infoNameMap[serverity] ?? ""),
      isLong: message.length > 30,
      isIconVisible: true,
    );
  });
}
