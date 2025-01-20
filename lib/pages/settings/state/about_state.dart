import 'package:nftools/messages/about.pb.dart';

class AboutState {
  String version = "";
  String newestVersion = "";
  List<VersionHistoryMsg> history = [];
  bool isInstalling = false;
}