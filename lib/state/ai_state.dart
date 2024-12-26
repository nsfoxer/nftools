import 'package:fluent_ui/fluent_ui.dart';

import '../utils/log.dart';

class AiState {
  // 展示结果
  TextEditingController displayController = TextEditingController();
  // 输入问题
  TextEditingController questController = TextEditingController();

  // 账户信息输入表单
  GlobalKey<FormState> formKey = GlobalKey();
  // user控制器
  TextEditingController appIdController = TextEditingController();
  // passwd控制器
  TextEditingController secretController = TextEditingController();

  void dispose() {
    info("dispose start");
    appIdController.dispose();
    secretController.dispose();
    questController.dispose();
    displayController.dispose();
  }
}