import 'dart:math';

import 'package:data_table_2/data_table_2.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/material.dart' as $me;
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';
import 'package:nftools/controller/sync_file_controller.dart';
import 'package:nftools/utils/nf-widgets.dart';

import '../messages/syncfile.pb.dart';

class SyncFilePage extends StatelessWidget {
  const SyncFilePage({super.key});

  void _showAccountSetting(
      BuildContext context, SyncFileController logic) async {
    var typography = FluentTheme.of(context).typography;
    final result = await showDialog<String>(
        context: context,
        builder: (context) => ContentDialog(
            title: Text("账户管理", style: typography.subtitle),
            content: SizedBox(
                // width: 300,
                // height: 260,
                child:  Form(
              key: logic.state.formKey,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  InfoLabel(
                      label: "服务器地址",
                      child: TextFormBox(
                        controller: logic.state.urlController,
                        keyboardType: TextInputType.text,
                        placeholder: "https://dav.xxxx.com/dav/",
                        enableSuggestions: false,
                        validator: (v) {
                          if (v!.startsWith("http://") ||
                              v.startsWith("https://")) {
                            return null;
                          }
                          return "必须以http://或https://开头";
                        },
                      )),
                  InfoLabel(
                      label: "账户",
                      child: TextFormBox(
                        controller: logic.state.userController,
                        keyboardType: TextInputType.text,
                        placeholder: "username",
                        enableSuggestions: false,
                        validator: (v) {
                          if (v == '') {
                            return "数据不能为空";
                          }
                          return null;
                        },
                      )),
                  InfoLabel(
                      label: "密码",
                      child: TextFormBox(
                        controller: logic.state.passwdController,
                        keyboardType: TextInputType.visiblePassword,
                        obscureText: true,
                        placeholder: "passwd",
                        enableSuggestions: false,
                        validator: (v) {
                          if (v == '') {
                            return "数据不能为空";
                          }
                          return null;
                        },
                      )),
                    ],
              ),
            )),
          actions: [
            FilledButton(child: Text("提交"), onPressed: () {
             if (!logic.state.formKey.currentState!.validate()) {
               return;
             }
            }),
            Button(child: Text("取消"), onPressed: (){
              context.pop();
            })
          ],
        ),
          
    );
  }

  @override
  Widget build(BuildContext context) {
    var typography = FluentTheme.of(context).typography;
    var table = GetBuilder<SyncFileController>(builder: (logic) {
      return LoadingWidgets(
          loading: logic.state.isLoading,
          child: PaginatedDataTable2(
            rowsPerPage: 5,
            onPageChanged: (page) {},
            columns: [
              DataColumn2(label: Text("本地", style: typography.bodyStrong)),
              DataColumn2(label: Text("远端", style: typography.bodyStrong)),
              DataColumn2(label: Text("状态", style: typography.bodyStrong)),
              DataColumn2(label: Text("操作", style: typography.bodyStrong)),
            ],
            source: SourceData(logic.state.fileList, logic),
          ));
    });
    return ScaffoldPage(
      header: PageHeader(
        title: const Text("文件同步"),
        commandBar: GetBuilder<SyncFileController>(builder: (logic) {
          return CommandBar(
            mainAxisAlignment: MainAxisAlignment.end,
            overflowItemAlignment: MainAxisAlignment.end,
            primaryItems: [
              CommandBarButton(
                  icon: Icon(FluentIcons.account_management),
                  label: Text("账户管理"),
                  onPressed: () {
                    _showAccountSetting(context, logic);
                  }),
            ],
          );
        }),
      ),
        content: table
    );
  }
}

class SourceData extends $me.DataTableSource {
  SourceData(this.fileList, this.logic);

  final List<FileMsg> fileList;
  final SyncFileController logic;

  @override
  $me.DataRow? getRow(int index) {
    var file = fileList[index];
    return DataRow2(cells: [
      $me.DataCell(Text(file.localDir)),
      $me.DataCell(Text(file.remoteDir)),
      $me.DataCell(Text(file.status.name)),
      $me.DataCell(Text(file.new_4.toString())),
    ]);
  }

  @override
  bool get isRowCountApproximate => false;

  @override
  int get rowCount => fileList.length;

  @override
  int get selectedRowCount => 0;
}
