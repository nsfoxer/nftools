import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:nftools/controller/sync_file_controller.dart';
import 'package:tolyui/form/form.dart';
import 'package:tolyui/tolyui.dart';

import '../common/style.dart';
import '../utils/nf-widgets.dart';

class MainPage extends StatefulWidget {
  const MainPage({Key? key}) : super(key: key);

  @override
  _MainPageState createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  bool desc = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
        child: Padding(
            padding: EdgeInsets.all(NFLayout.v1),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "主页",
                  style: NFTextStyle.h1,
                ),
                NFLayout.vlineh1,
                Text(
                  "同步",
                  style: NFTextStyle.h2,
                ),
                NFLayout.vlineh2,
                NFCard(
                  child: SyncFile(),
                )
              ],
            )));
  }
}

class SyncFile extends StatelessWidget {
  final TextEditingController _textEditingController = TextEditingController();

  void _submit(SyncFileController logic) {
    var v = _textEditingController.text.trim();
    if (v.isEmpty) {
      return;
    }
    logic.addFile(v);
    _textEditingController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return GetBuilder<SyncFileController>(builder: (logic) {
      List<Widget> children = [];
      for (var value in logic.state.files) {
        children.add(ListTile(
          title: Text(value),
        ));
      }

      children.add(TolyInput(
        hintText: "添加数据",
        controller: _textEditingController,
        onSubmitted: (_) => _submit(logic),
        tailingBuilder: SlotBuilder(
          builder: (_, __) => Icon(Icons.add),
          onTap: () => _submit(logic),
        ),
      ));

      return Column(
        children: children,
      );
    });
  }
}
