import '../common/constants.dart';
import '../src/bindings/bindings.dart';
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
  return stream.map((x) => BaiduAiRspMsg.bincodeDeserialize(x));
}

// 获取kv
Future<BaiduAiKeyReqMsg> getKV() async {
  var data = await sendRequest<EmptyMsg>(_service, _getKV, null);
  return BaiduAiKeyReqMsg.bincodeDeserialize(data);
}

// set kv
Future<void> setKV(String appId, String secret) async {
  final data = BaiduAiKeyReqMsg(apiKey: appId, secret: secret);
  await sendRequest<BaiduAiKeyReqMsg>(_service, _setKV, data);
}

// 刷新token
Future<void> refreshToken() async {
  await sendRequest<EmptyMsg>(_service, _refresh, null);
}

// 获取所有问题列表
Future<List<QuestionMsg>> getQuestionList() async {
  final data =
      await sendRequest<EmptyMsg>(_service, _getQuestionList, null);
  return QuestionListMsg.bincodeDeserialize(data).questionList;
}

// 获取指定问题的请求数据
Future<List<String>> getQuestion(int id) async {
  final data = await sendRequest(_service, _getQuestion, UintFiveMsg(value: id));
  return VecStringMsg.bincodeDeserialize(data).values;
}

// 新增问题
Future<void> addQuestion(int id) async {
  await sendRequest(_service, _addQuestion, UintFiveMsg(value: id));
}

// 删除问题
Future<void> delQuestion(int id) async {
  await sendRequest(_service, _delQuestion, UintFiveMsg(value: id));
}

// 获取当前model
Future<ModelEnumMsg> getModel() async {
  final data = await sendRequest<EmptyMsg>(_service, _getModel, null);
  return AiModelMsg.bincodeDeserialize(data).modelEnum;
}

// 设置当前model
Future<void> setModel(ModelEnumMsg model) async {
  await sendRequest(_service, _setModel, AiModelMsg(modelEnum: model));
}

