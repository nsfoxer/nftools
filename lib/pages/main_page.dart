import 'package:flutter/material.dart';
import 'package:nftools/messages/basic.pbserver.dart';
import 'package:tolyui/tolyui.dart';

class MainPage extends StatelessWidget {
  const MainPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: TolyAction(
        child: StreamBuilder(
            stream: Response.rustSignalStream,
            builder: (context, snapshot) {
              final signal = snapshot.data;
              if (signal == null) {
                return Text("None");
              }
              return Text(signal.message.resp);
            }),
        onTap: () {
          Request(req: "请求一些数据").sendSignalToRust();
          $message.success(message: "message");
        },
      ),
    );
  }
}
