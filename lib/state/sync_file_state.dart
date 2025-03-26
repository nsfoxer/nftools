import 'package:data_table_2/data_table_2.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:nftools/messages/syncfile.pb.dart';

class SyncFileState {
  // 是否登录成功
  bool isLogin = false;

  // 是否正在加载
  bool isLoading = true;
  // 所有文件列表
  List<FileMsg> fileList = [];

  // 是否锁定账户信息
  bool accountInfoLock = false;

  // 账户信息输入表单
  GlobalKey<FormState> formKey = GlobalKey();
  // url控制器
  TextEditingController urlController = TextEditingController();
  // user控制器
  TextEditingController userController = TextEditingController();
  // passwd控制器
  TextEditingController passwdController = TextEditingController();

  // 新增同步文件夹输入表单
  GlobalKey<FormState> syncFormKey = GlobalKey();
  // Tag控制器
  TextEditingController tagController = TextEditingController();
  // add file local
  TextEditingController addSyncDirController = TextEditingController();

  PaginatorController pageController = PaginatorController();

  int timer = 0;

  void dispose() {
    urlController.dispose();
    userController.dispose();
    passwdController.dispose();
    tagController.dispose();
    addSyncDirController.dispose();
    pageController.dispose();
  }

}
