import 'package:nftools/messages/ai.pb.dart';

import '../messages/common.pb.dart';
import 'api.dart';

const String _service = "BaiduAiService";
const String _question = "question";

// ai 测试
Stream<BaiduAiRspMsg> question(String msg) {
  var stream =
      sendRequestStream(_service, _question, StringMessage(value: msg));
  return stream.map((x) => BaiduAiRspMsg.fromBuffer(x));
}
