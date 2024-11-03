import 'package:fluent_ui/fluent_ui.dart';
import 'package:nftools/main.dart';

BuildContext? getCurrentContext() {
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

void _print(String message, InfoBarSeverity serverity) async {
  debugPrint("${serverity.name}: $message");
  final context = getCurrentContext();
  if (context == null) {
    return;
  }
  await displayInfoBar(context, builder: (context, close) {
    return InfoBar(
      content: Text(message),
      severity: serverity, title: Text(serverity.name.toUpperCase()),
    );
  });
}
