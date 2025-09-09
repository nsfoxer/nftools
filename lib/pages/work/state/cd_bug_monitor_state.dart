import 'package:fluent_ui/fluent_ui.dart';

class CdBugsMonitorState {

  // 配置表单key
  GlobalKey<FormState> formKey = GlobalKey();
  // 配置
  final TextEditingController urlController = TextEditingController();
  final TextEditingController cookieController = TextEditingController();
  bool enableMonitor = false;

  // bug数量
  int? count;

}