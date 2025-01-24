
import 'package:nftools/messages/common.pb.dart';
import 'package:nftools/messages/utils.pb.dart';

import 'api.dart';

const String _service = "BaseService";
const String _close = "close";

// 结束所有服务
Future<String> closeRust() async {
  var data = await sendRequest<EmptyMessage>
    (_service, _close, null);
  return StringMessage.fromBuffer(data).value;
}

