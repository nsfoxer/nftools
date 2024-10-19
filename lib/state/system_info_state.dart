const _size = 300;
class SystemInfoState {
  List<ValueInfo> cpuInfos = [];
  List<ValueInfo> memoryInfos = [];
  

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