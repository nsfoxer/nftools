
import 'package:fluent_ui/fluent_ui.dart';
import 'package:nftools/main.dart';

/// 获取全局context
BuildContext? getContext() {
  return rootNavigatorKey.currentState?.context;
}

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

void _print(String message, InfoBarSeverity serverity) {
  debugPrint("${serverity.name}: $message");
  var context = getContext();
  if (context == null) {
    return;
  }
  displayInfoBar(context, builder: (context, close) {
    return InfoBar(
      title: Text(message),
      severity: serverity,
    );
  });
}