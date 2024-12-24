import 'dart:async';
import 'dart:typed_data';

import 'package:fixnum/fixnum.dart';
import 'package:nftools/utils/log.dart';
import 'package:protobuf/protobuf.dart' as $pb;
import 'package:nftools/messages/base.pb.dart';
import 'package:rinf/rinf.dart';

// 请求序列
Int64 _seq = Int64.ZERO;
// 响应流
Map<Int64, Completer<List<int>>> _reqMap = {};
Map<Int64, StreamController<List<int>>> _reqStreamMap = {};

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

// 发送请求，并响应
// 返回序列化后的响应数据
Future<List<int>> sendRequest<T extends $pb.GeneratedMessage>(
    String service, String func, T? request) {
  // 序列号
  final id = _seq++;
  // 记录发送信息
  Completer<List<int>> completer = Completer();
  _reqMap[id] = completer;
  // 发送
  BaseRequest(
    id: id,
    service: service,
    func: func,
    isStream: false,
  ).sendSignalToRust(request?.writeToBuffer() ?? Uint8List(0));
  // 返回
  return completer.future;
}

// 发送请求，并流式响应
Stream<List<int>> sendRequestStream<T extends $pb.GeneratedMessage>(
    String service, String func, T? request) {
  // 序列号
  final id = _seq++;
  // 记录发送信息
  StreamController<List<int>> controller = StreamController();
  _reqStreamMap[id] = controller;
  // 发送
  BaseRequest(
    id: id,
    service: service,
    func: func,
    isStream: true,
  ).sendSignalToRust(request?.writeToBuffer() ?? Uint8List(0));
  // 返回
  return controller.stream;
}

// 处理流式响应
void _handleStream(RustSignal<BaseResponse> data) {
  final rsp = data.message;
  var controller = _reqStreamMap[rsp.id];
  if (controller == null) {
    error("无法处理响应:无法找到对应id：${rsp.id}");
    return;
  }
  controller.add(data.binary);
  if (rsp.isEnd) {
    controller.close();
  }
}