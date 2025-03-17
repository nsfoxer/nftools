import 'dart:io';

import 'package:data_table_2/data_table_2.dart';
import 'package:file_picker/file_picker.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/material.dart' as $me;
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';
import 'package:nftools/common/style.dart';
import 'package:nftools/controller/sync_file_controller.dart';
import 'package:nftools/utils/log.dart';
import 'package:nftools/utils/nf_widgets.dart';
import 'package:nftools/utils/utils.dart';

import '../messages/syncfile.pb.dart';

class SyncFilePage extends StatelessWidget {
  const SyncFilePage({super.key});

  void _showAccountSetting(BuildContext context) async {
    var typography = FluentTheme.of(context).typography;
    var color = primaryColor(context);
    await showDialog<String>(
        context: context,
        builder: (context) => GetBuilder<SyncFileController>(builder: (logic) {
              return ContentDialog(
                title: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("账户管理", style: typography.subtitle),
                    InfoLabel(
                        label: logic.state.accountInfoLock ? "已锁定" : "可编辑",
                        isHeader: false,
                        child: IconButton(
                            icon: Icon(logic.state.accountInfoLock
                                ? FluentIcons.lock
                                : FluentIcons.unlock),
                            onPressed: () {
                              logic.changeAccountLogic();
                            })),
                  ],
                ),
                content: SizedBox(
                    child: Form(
                  key: logic.state.formKey,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      InfoLabel(
                          label: "服务器地址",
                          child: TextFormBox(
                            controller: logic.state.urlController,
                            readOnly: logic.state.accountInfoLock,
                            cursorColor: color,
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
                            cursorColor: color,
                            readOnly: logic.state.accountInfoLock,
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
                            cursorColor: color,
                            readOnly: logic.state.accountInfoLock,
                            keyboardType: TextInputType.visiblePassword,
                            obscureText: true,
                            placeholder: "密码",
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
                  FilledButton(
                      onPressed: logic.state.accountInfoLock ? null :  () async {
                        if (!logic.state.formKey.currentState!.validate()) {
                          return;
                        }
                        if (await logic.submitAccount()) {
                          logic.state.accountInfoLock = true;
                          info("登录成功");
                          logic.listFiles();
                          if (context.mounted) {
                            context.pop();
                          }
                        } else {
                          error("登录失败");
                        }
                      },
                      child: const Text("提交")),
                  Button(
                      child: const Text("取消"),
                      onPressed: () {
                        logic.state.formKey.currentState!.reset();
                        context.pop();
                      })
                ],
              );
            }));
  }

  void _showAddSyncDir(BuildContext context) async {
    var typography = FluentTheme.of(context).typography;
    var color = primaryColor(context);
    await showDialog(
        context: context,
        builder: (context) => GetBuilder<SyncFileController>(builder: (logic) {
              return ContentDialog(
                title: Text("新增同步文件夹", style: typography.subtitle),
                content: SizedBox(
                    child: Form(
                  key: logic.state.syncFormKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      InfoLabel(
                          label: "标签",
                          child: TextFormBox(
                            controller: logic.state.tagController,
                            cursorColor: color,
                            keyboardType: TextInputType.text,
                            placeholder: "标签",
                            enableSuggestions: false,
                            validator: (v) {
                              if (v!.isEmpty) {
                                return "不能为空";
                              }
                              return null;
                            },
                          )),
                      InfoLabel(
                          label: "文件地址",
                          child: TextFormBox(
                            readOnly: true,
                            controller: logic.state.addSyncDirController,
                            placeholder: "选取一个要同步的文件夹",
                            validator: (v) {
                              if (v!.isEmpty) {
                                return "不能为空";
                              }
                              return null;
                            },
                            onTap: () async {
                              final dir = await _addLocalDir();
                              if (dir != null) {
                                logic.state.addSyncDirController.text = dir;
                              }
                            },
                          )),
                    ],
                  ),
                )),
                actions: [
                  FilledButton(
                      child: const Text("添加"),
                      onPressed: () {
                        if (!logic.state.syncFormKey.currentState!.validate()) {
                          return;
                        }
                        logic.addSyncDir(logic.state.addSyncDirController.text,
                            logic.state.tagController.text);
                        logic.state.tagController.text = "";
                        logic.state.addSyncDirController.text = "";
                        context.pop();
                      }),
                  Button(
                      child: const Text("取消"),
                      onPressed: () {
                        logic.state.tagController.text = "";
                        logic.state.addSyncDirController.text = "";
                        context.pop();
                      })
                ],
              );
            }));
  }

  @override
  Widget build(BuildContext context) {
    var typography = FluentTheme.of(context).typography;
    var table = GetBuilder<SyncFileController>(builder: (logic) {
      return LoadingWidgets(
        loading: logic.state.isLoading,
        child: PaginatedDataTable2(
          controller: logic.state.pageController,
          hidePaginator: true,
          empty: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                FluentIcons.cloud_flow,
                size: 60,
              ),
              NFLayout.vlineh1,
              Text("无数据")
            ],
          ),
          rowsPerPage: 7,
          minWidth: 800,
          fixedLeftColumns: 1,
          lmRatio: 1.6,
          columns: [
            DataColumn2(label: Text("操作", style: typography.bodyStrong)),
            DataColumn2(
                label: Text("本地", style: typography.bodyStrong),
                size: ColumnSize.L),
            DataColumn2(
                label: Text("标签", style: typography.bodyStrong),
                size: ColumnSize.M),
            DataColumn2(
                label: Text("状态", style: typography.bodyStrong),
                size: ColumnSize.S),
            DataColumn2(
                label: Text("新增 删除 变更", style: typography.bodyStrong),
                size: ColumnSize.M),
          ],
          source: SourceData(logic.state.fileList, logic, context),
        ),
      );
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
                  icon: const Icon(FluentIcons.account_management),
                  label: const Text("账户管理"),
                  onPressed: () {
                    _showAccountSetting(context);
                  }),
              CommandBarButton(
                icon: const Icon(FluentIcons.fabric_folder),
                label: const Text("新增文件夹"),
                onPressed: () {
                  _showAddSyncDir(context);
                },
              ),
              CommandBarButton(
                  icon: const Icon(FluentIcons.refresh),
                  label: const Text("刷新"),
                  onPressed: () {
                    logic.refreshList();
                  }),
            ],
          );
        }),
      ),
      content: table,
      bottomBar: GetBuilder<SyncFileController>(builder: (logic) {
        return Padding(
            padding: const EdgeInsets.fromLTRB(0, 0, 15, 3),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  "第${logic.currentPage()}页 - 共${logic.pageCount()}页",
                  style: typography.caption,
                ),
                NFLayout.hlineh3,
                Tooltip(
                    message: "上一页",
                    child: IconButton(
                        icon: const Icon(FluentIcons.chevron_left_med),
                        onPressed: logic.currentPage() == 1
                            ? null
                            : () {
                                logic.prevPage();
                              })),
                NFLayout.hlineh3,
                Tooltip(
                    message: "下一页",
                    child: IconButton(
                        icon: const Icon(FluentIcons.chevron_right_med),
                        onPressed: logic.currentPage() == logic.pageCount()
                            ? null
                            : () {
                                logic.nextPage();
                              })),
              ],
            ));
      }),
    );
  }
}

// 获取一个本地文件夹路径
Future<String?> _addLocalDir() async {
  String? directoryPath = await FilePicker.platform.getDirectoryPath();
  if (directoryPath == null) {
    return null;
  }
  if (Platform.isWindows) {
    directoryPath += "\\";
  } else if (Platform.isLinux) {
    directoryPath += "/";
  }
  return directoryPath;
}

class SourceData extends $me.DataTableSource {
  SourceData(this.fileList, this.logic, this.context);

  final List<FileMsg> fileList;
  final SyncFileController logic;
  final BuildContext context;

  @override
  $me.DataRow? getRow(int index) {
    var typography = FluentTheme.of(context).typography;
    var file = fileList[index];
    return DataRow2(cells: [
      $me.DataCell(
        () {
          // 远端无记录，直接删除
          if (file.remoteDir.isEmpty) {
            return Tooltip(
                message: "无远端记录，删除同步记录。\n(此操作不会对实际文件产生影响)",
                child: FilledButton(
                    child: const Text("删除"),
                    onPressed: () {
                      logic.deleteLocalDir(file.localDir);
                    }));
          }
          // 本地无记录，添加本地文件
          if (file.localDir.isEmpty) {
            return Tooltip(
                message: "无本地同步文件夹，新增本地文件夹以建立同步关系。\n(本地文件夹要求为空文件夹)",
                child: Button(
                    child: const Text("添加同步"),
                    onPressed: () async {
                      var dirPath = await _addLocalDir();
                      if (dirPath != null) {
                        logic.addLocalDir(dirPath, file.remoteDir);
                      }
                    }));
          }
          // 一般操作
          return Row(
            children: [
              Button(
                  onPressed: file.status == FileStatusEnum.SYNCED
                      ? null
                      : () async {
                          await logic.syncDir(file.remoteDir);
                        },
                  child: const Text("同步")),
              NFLayout.hlineh3,
              FilledButton(
                  child: const Text("删除"),
                  onPressed: () async {
                    if (await confirmDialog(
                        context, "确认删除", "此操作不会删除本地文件，但会导致远端服务器上文件全部删除!!！")) {
                      logic.deleteRemoteDir(file.remoteDir);
                    }
                  }),
            ],
          );
        }(),
      ),
      $me.DataCell(Tooltip(
          message: file.localDir,
          child: Text(
            file.localDir,
            overflow: TextOverflow.ellipsis,
            style: typography.caption,
            maxLines: 2,
          ))),
      $me.DataCell(Tooltip(
          message: file.tag,
          child: Text(
            file.tag,
            overflow: TextOverflow.ellipsis,
            style: typography.caption,
            maxLines: 2,
          ))),
      $me.DataCell(() {
        var desc = "";
        switch (file.status) {
          case FileStatusEnum.DOWNLOAD:
            desc = "待下载";
            break;
          case FileStatusEnum.SYNCED:
            desc = "已同步";
            break;
          case FileStatusEnum.UPLOAD:
            desc = "待上传";
            break;
        }
        return Text(
          desc,
          style: typography.caption,
        );
      }()),
      $me.DataCell(
          Text("${file.new_4}        ${file.del}        ${file.modify}", style: typography.caption,)),
    ]);
  }

  @override
  bool get isRowCountApproximate => false;

  @override
  int get rowCount => fileList.length;

  @override
  int get selectedRowCount => 0;
}
