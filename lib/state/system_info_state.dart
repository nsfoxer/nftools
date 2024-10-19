class SystemInfoState {
  Map<String, (int, int)> timeSpanCombo = {
    "5s": (5, 1),
    "1min": (60, 1),
    "5min": (300, 1),
    "10min": (300, 2),
    "30min": (300,6),
    "1h": (600, 6),
    "5h": (900, 20),
    "12h": (1200, 36),
    "24h": (1200, 72),
  };
  List<ValueInfo> cpuInfos = [];
  List<ValueInfo> memoryInfos = [];

  int _size = 60;
  String selected = "1min";

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