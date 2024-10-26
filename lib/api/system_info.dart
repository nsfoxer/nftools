
import 'package:nftools/messages/common.pb.dart';
import 'package:nftools/messages/system_info.pb.dart';

import 'api.dart';

const String _service1 = "SystemInfo";
const String _getCpu = "get_cpu";
const String _getRam = "get_ram";


Future<ChartInfo> getCpu() async {
  var r = await sendRequest<EmptyMessage>(_service1, _getCpu, null);
  return ChartInfo.fromBuffer(r);
}

Future<ChartInfo> getRam() async {
  var r = await sendRequest<EmptyMessage>(_service1, _getRam, null);
  return ChartInfo.fromBuffer(r);
}


