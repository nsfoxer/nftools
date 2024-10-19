
import 'package:nftools/messages/common.pb.dart';
import 'package:nftools/messages/system_info.pb.dart';

import 'api.dart';

const String _service1 = "SystemInfo";
const String _getCpu = "get_cpu";
const String _getRam = "get_ram";


Future<CpuInfoRsp> getCpu() async {
  var r = await sendRequest<EmptyMessage>(_service1, _getCpu, null);
  return CpuInfoRsp.fromBuffer(r);
}

Future<RamInfoRsp> getRam() async {
  var r = await sendRequest<EmptyMessage>(_service1, _getRam, null);
  return RamInfoRsp.fromBuffer(r);
}


