import 'package:nftools/messages/ai.pb.dart';

import '../common/constants.dart';
import '../messages/common.pb.dart';
import 'api.dart';

const String _service = ServiceNameConstant.ai;
const String _question = "question";
const String _getKV = "get_kv";
const String _setKV = "set_kv";
const String _refresh = "refresh_token";
const String _getQuestionList = "get_question_list";
const String _getQuestion = "get_question";
const String _addQuestion = "new_question";
const String _delQuestion = "del_question";
const String _getModel = "get_model";
const String _setModel = "set_model";

// ai 测试
Stream<BaiduAiRspMsg> quest(String msg, int id) {
  var stream =
      sendRequestStream(_service, _question, QuestionMsg(id: id, desc: msg));
  return stream.map((x) => BaiduAiRspMsg.fromBuffer(x));
}

// 获取kv
Future<BaiduAiKeyReqMsg> getKV() async {
  var data = await sendRequest<EmptyMessage>(_service, _getKV, null);
  return BaiduAiKeyReqMsg.fromBuffer(data);
}

// set kv
Future<void> setKV(String appId, String secret) async {
  final data = BaiduAiKeyReqMsg(apiKey: appId, secret: secret);
  await sendRequest<BaiduAiKeyReqMsg>(_service, _setKV, data);
}

// 刷新token
Future<void> refreshToken() async {
  await sendRequest<EmptyMessage>(_service, _refresh, null);
}

// 获取所有问题列表
Future<List<QuestionMsg>> getQuestionList() async {
  final data =
      await sendRequest<EmptyMessage>(_service, _getQuestionList, null);
  return QuestionListMsg.fromBuffer(data).questionList;
}

// 获取指定问题的请求数据
Future<List<String>> getQuestion(int id) async {
  final data = await sendRequest(_service, _getQuestion, Uint32Message(value: id));
  return VecStringMessage.fromBuffer(data).values;
}

// 新增问题
Future<void> addQuestion(int id) async {
  await sendRequest(_service, _addQuestion, Uint32Message(value: id));
}

// 删除问题
Future<void> delQuestion(int id) async {
  await sendRequest(_service, _delQuestion, Uint32Message(value: id));
}

// 获取当前model
Future<ModelEnum> getModel() async {
  final data = await sendRequest<EmptyMessage>(_service, _getModel, null);
  return AiModelMsg.fromBuffer(data).modelEnum;
}

// 设置当前model
Future<void> setModel(ModelEnum modelEnum) async {
  await sendRequest(_service, _setModel, AiModelMsg(modelEnum: modelEnum));
}

