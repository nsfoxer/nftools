import 'package:fluent_ui/fluent_ui.dart';

import '../src/bindings/bindings.dart';

class AiState {
  // 对话列表controller
  ScrollController scrollController = ScrollController();

  // 当前对话数据
  AiContentData contentData = AiContentData(0, "", []);

  // 是否已登录
  bool isLogin = false;

  // 当前是否结束
  bool isLoading = false;

  // 对话列表 (id, desc)
  List<(int, String)> idList = [];

  // 输入问题
  TextEditingController questController = TextEditingController();

  // 账户信息输入表单
  GlobalKey<FormState> formKey = GlobalKey();

  // user控制器
  TextEditingController appIdController = TextEditingController();

  // passwd控制器
  TextEditingController secretController = TextEditingController();

  ModelEnumMsg modelEnum = ModelEnumMsg.baidu;

  void dispose() {
    appIdController.dispose();
    secretController.dispose();
    questController.dispose();
    scrollController.dispose();
  }

  void reInit() {
    contentData = AiContentData(0, "", []);
    isLogin = false;
    isLoading = false;
    idList = [];
    appIdController.clear();
    secretController.clear();
    scrollController.dispose();
    scrollController = ScrollController();
    modelEnum = ModelEnumMsg.baidu;
  }
}

class AiContentData {
  // 对话id
  final int id;

  // 描述
  String description;

  // 倒序 第一条是assistant 第二条是为user
  final List<String> contents;

  AiContentData(this.id, this.description, this.contents);

  @override
  String toString() {
    return 'AiContentData{id: $id, description: $description, contents: $contents}';
  }
}
