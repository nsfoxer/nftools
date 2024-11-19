import 'package:nftools/messages/syncfile.pb.dart';

class SyncFileState {

  // 是否正在加载
  bool isLoading = true;
  // 所有文件列表
  List<FileMsg> fileList = [];
  // 账号信息
  late WebDavConfigMsg accountInfo;
}