import 'package:data_table_2/data_table_2.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:nftools/controller/sync_file_controller.dart';
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
            padding: const EdgeInsets.all(NFLayout.v1),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "主页",
                  style: NFTextStyle.h1,
                ),
                NFLayout.vlineh1,
                const Text(
                  "同步",
                  style: NFTextStyle.h2,
                ),
                NFLayout.vlineh2,
                _SyncFileHead(),
                NFCard(
                  child: SyncFile(),
                )
              ],
            )));
  }
}

Future<void> _dialogBuilder(BuildContext context) {
  return showDialog(
      context: context,
      builder: (BuildContext context) {
        return GetBuilder<SyncFileController>(builder: (logic) {
          return Dialog(
              child: Container(
            padding: const EdgeInsets.all(NFLayout.v1 * 2),
            width: 600,
            height: 400,
            child: Column(
              children: [
                TextField(
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: "服务器地址",
                    hintText : "https://dav.jianguoyun.com/dav/",
                    prefixIcon: Icon(Icons.web)
                  ),
                  keyboardType: TextInputType.url,
                  controller: logic.state.controller1,
                ),
                TextField(
                  decoration: const InputDecoration(
                      labelText: "账户",
                      prefixIcon: Icon(Icons.person)
                  ),
                  controller: logic.state.controller2,
                ),
                TextField(
                  decoration: const InputDecoration(
                      labelText: "密码",
                      prefixIcon: Icon(Icons.password)
                  ),
                  controller: logic.state.controller3,
                  obscureText: true,
                ),
                NFLayout.vlineh1,
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ElevatedButton.icon(onPressed: () {

                    }, label: Text("确认"), icon: Icon(Icons.save))
                  ],
                )

              ],
            ),
          ));
        });
      });
}

class _SyncFileHead extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GetBuilder<SyncFileController>(builder: (logic) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TolyAction(
              tooltip: "配置",
              child: const Icon(Icons.settings),
              onTap: () {
                _dialogBuilder(context);
              })
        ],
      );
    });
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
          builder: (_, __) => const Icon(Icons.add),
          onTap: () => _submit(logic),
        ),
      ));

      return SizedBox(
        height: 500,
        child: DataTable2(
          columnSpacing: 2,
          horizontalMargin: 2,
          headingRowHeight: 40,
          dataRowHeight: 30,
          // minWidth: 100,
          columns: [
            const DataColumn(
              label: Text("文件"),
            ),
            const DataColumn(
              label: Text("本地更新时间"),
            ),
            const DataColumn(
              label: Text("远端更新时间"),
            ),
            const DataColumn2(label: Text("同步状态")),
            const DataColumn2(label: Text("操作"), size: ColumnSize.S),
          ],
          rows: List<DataRow>.generate(
              100,
              (index) => DataRow(cells: [
                    DataCell(Text('A' * (10 - index % 10))),
                    DataCell(Text('B' * (10 - (index + 5) % 10))),
                    DataCell(Text('C' * (15 - (index + 5) % 10))),
                    DataCell(Text('C' * (15 - (index + 5) % 10))),
                    DataCell(Text('C' * (15 - (index + 5) % 10))),
                  ])),
        ),
      );
    });
  }
}
