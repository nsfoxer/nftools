class SystemInfoState {
  Map<String, int> timeSpanCombo = {
    "1min": 60,
    "5min": 300,
    "10min": 600,
    "30min": 1800,
    "1h": 3600,
  };

  // 历史数据 cpu
  List<ValueInfo> cpuInfos = [];

  // 实时数据 cpu
  List<ValueInfo> liveCpuInfos = [];

  // 历史数据 mem
  List<ValueInfo> memoryInfos = [];

  // 实时数据 mem
  List<ValueInfo> liveMemoryInfos = [];

  // 是否为实时更新
  bool isLive = true;

  // 历史图表展示
  // 开始时间
  DateTime? startTime;

  // 开始时间
  DateTime? endTime;

  String selected = "10min";

  void addLiveCpuInfo(double percent) {
    liveCpuInfos.add(ValueInfo(DateTime.now(), percent));
    final len = liveCpuInfos.length - timeSpanCombo[selected]!;
    if (len > 0) {
      liveCpuInfos.removeRange(0, len);
    }
  }

  void addLiveMemInfo(double percent) {
    liveMemoryInfos.add(ValueInfo(DateTime.now(), percent));
    final len = liveMemoryInfos.length - timeSpanCombo[selected]!;
    if (len > 0) {
      liveMemoryInfos.removeRange(0, len);
    }
  }
}

class ValueInfo {
  final DateTime time;
  final double percent;

  const ValueInfo(this.time, this.percent);
}
