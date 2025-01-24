
import 'package:nftools/messages/common.pb.dart';
import 'package:nftools/messages/system_info.pb.dart';

import 'api.dart';

const String _service = "SystemInfo";
const String _getCpu = "get_cpu";
const String _getRam = "get_ram";
const String _getCpuDatas = "get_cpu_datas";
const String _getRamDatas = "get_mem_datas";


Future<ChartInfo> getCpu() async {
  var r = await sendRequest<EmptyMessage>(_service, _getCpu, null);
  return ChartInfo.fromBuffer(r);
}

Future<ChartInfo> getRam() async {
  var r = await sendRequest<EmptyMessage>(_service, _getRam, null);
  return ChartInfo.fromBuffer(r);
}

Future<ChartInfoRsp> getCpus(DateTime startTime, DateTime endTime) async {
  final req = ChartInfoReq(startTime: startTime.millisecondsSinceEpoch ~/ 1000, endTime: endTime.millisecondsSinceEpoch ~/ 1000);
  var r = await sendRequest(_service, _getCpuDatas, req);
  return ChartInfoRsp.fromBuffer(r);
}

Future<ChartInfoRsp> getRams(DateTime startTime, DateTime endTime) async {
  final req = ChartInfoReq(startTime: startTime.millisecondsSinceEpoch ~/ 1000, endTime: endTime.millisecondsSinceEpoch ~/ 1000);
  var r = await sendRequest(_service, _getRamDatas, req);
  return ChartInfoRsp.fromBuffer(r);
}