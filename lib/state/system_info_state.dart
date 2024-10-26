import 'package:fluent_ui/fluent_ui.dart';

class SystemInfoState {
  Map<String, (int, int)> timeSpanCombo = {
    "1min": (60, 1),
    "5min": (300, 1),
    "10min": (600, 1),
    "30min": (900,2),
    "1h": (1200, 3),
  };
  List<ValueInfo> cpuInfos = [];
  List<ValueInfo> memoryInfos = [];

  int _size = 60;
  String selected = "10min";

  void setSize(int size) {
    _size = size;
  }

  void addCpuInfo(double percent) {
    cpuInfos.add(ValueInfo(DateTime.now(), percent));
    if (cpuInfos.length > _size) {
      cpuInfos.removeAt(0);
    }
  }

  void addMemInfo(double percent) {
    memoryInfos.add(ValueInfo(DateTime.now(), percent));
    if (memoryInfos.length > _size) {
      memoryInfos.removeAt(0);
    }
  }

}

class ValueInfo {
  final DateTime time;
  final double percent;

  const ValueInfo(this.time, this.percent);
}