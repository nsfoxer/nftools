import 'package:fluent_ui/fluent_ui.dart';

/// info log
void info(String message, {BuildContext? context}) {
  _print(message, InfoBarSeverity.info, context);
}

/// warn log
void warn(String message, {BuildContext? context}) {
  _print(message, InfoBarSeverity.warning, context);
}

/// error log
void error(String message, {BuildContext? context}) {
  _print(message, InfoBarSeverity.error, context);
}

void _print(
    String message, InfoBarSeverity serverity, BuildContext? context) async {
  debugPrint("${serverity.name}: $message");
  if (context == null) {
    return;
  }
  await displayInfoBar(context, builder: (context, close) {
    return InfoBar(
      title: Text(message),
      severity: serverity,
    );
  });
}
