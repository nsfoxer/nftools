import 'dart:async';
import 'dart:typed_data';

import 'package:nftools/utils/log.dart';
import 'package:rinf/rinf.dart';

import '../src/bindings/bindings.dart';

// 请求序列
int _seq = 0;
// 响应流
Map<int, Completer<Uint8List>> _reqMap = {};
Map<int, StreamController<Uint8List>> _reqStreamMap = {};

// 启动监听响应数据
void initMsg() {
  BaseResponse.rustSignalStream.listen((data) {
    final rsp = data.message;
    if (rsp.isStream) {
      _handleStream(data);
      return;
    }
    var complete = _reqMap.remove(rsp.id);
    if (complete == null) {
      // 错误，没有请求id
      error("无法处理响应:无法找到对应id：${rsp.id}");
      return;
    }
    if (rsp.msg.isNotEmpty) {
      // 错误：处理错误
      error(rsp.msg);
      complete.completeError(rsp.msg);
    } else {
      complete.complete(data.binary);
    }
  });
}

// 定义一个 mixin 来约束 bincodeSerialize 方法
mixin ApiSerializable {
  Uint8List bincodeSerialize();
}


// 发送请求，并响应
// 返回序列化后的响应数据
Future<Uint8List> sendRequest<T extends ApiSerializable >(
    String service, String func, T? request) {
  // 序列号
  final id = _seq++;
  // 记录发送信息
  Completer<Uint8List> completer = Completer();
  _reqMap[id] = completer;
  // 发送
  BaseRequest(
    id: id,
    service: service,
    func: func,
    isStream: false,
  ).sendSignalToRust(request?.bincodeSerialize() ?? Uint8List(0));
  debug("sendRequest: id: $id service: $service func: $func");
  // 返回
  return completer.future;
}

// 发送请求，并流式响应
Stream<Uint8List> sendRequestStream<T extends ApiSerializable>(
    String service, String func, T? request) {
  // 序列号
  final id = _seq++;
  // 记录发送信息
  StreamController<Uint8List> controller = StreamController();
  _reqStreamMap[id] = controller;
  // 发送
  BaseRequest(
    id: id,
    service: service,
    func: func,
    isStream: true,
  ).sendSignalToRust(request?.bincodeSerialize() ?? Uint8List(0));
  // 返回
  return controller.stream;
}

// 处理流式响应
void _handleStream(RustSignalPack<BaseResponse> data) {
  debug("handleStream: ${data.message.id}");
  final rsp = data.message;
  var controller = _reqStreamMap[rsp.id];
  if (controller == null) {
    error("无法处理响应:无法找到对应id：${rsp.id}");
    return;
  }
  if (rsp.msg.isNotEmpty) {
    // 错误：处理错误
    error(rsp.msg);
    controller.addError(rsp.msg);
  } else if (data.binary.isNotEmpty) {
    controller.add(data.binary);
  }
  if (rsp.isEnd) {
    controller.close();
  }
}
