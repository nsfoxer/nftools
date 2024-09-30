import 'dart:async';
import 'dart:typed_data';

import 'package:fixnum/fixnum.dart';
import 'package:flutter/widgets.dart';
import 'package:protobuf/protobuf.dart' as $pb;
import 'package:nftools/messages/base.pb.dart';
import 'package:tolyui/tolyui.dart';

// 请求序列
Int64 _seq = Int64.ZERO;
// 响应流
Map<Int64, Completer<List<int>>> _reqMap = {};

// 启动监听响应数据
void initMsg() {
  BaseResponse.rustSignalStream.listen((data) {
    final rsp = data.message;
    var complete = _reqMap.remove(rsp.id);
    if (complete == null) {
      $message.errorNotice(
          title: const Text(
            "请求处理出错",
          ),
          subtitle: Text("无法找到标识为${rsp.id}的请求"));
      return;
    }
    if (rsp.msg.isNotEmpty) {
      $message.errorNotice(title: const Text("处理出错"), subtitle: Text(rsp.msg));
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
  )
      // request: request?.writeToBuffer())
      .sendSignalToRust(request?.writeToBuffer() ?? Uint8List(0));
  // 返回
  return completer.future;
}
