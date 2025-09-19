import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';
import 'package:nftools/common/style.dart';
import 'package:nftools/controller/sync_file_controller.dart';
import 'package:nftools/utils/log.dart';
import 'package:nftools/utils/nf_widgets.dart';
import 'package:nftools/utils/utils.dart';

import '../src/bindings/bindings.dart';

class SyncFilePage extends StatelessWidget {
  const SyncFilePage({super.key});

  void _showAccountSetting(BuildContext context) async {
    final typography = FluentTheme.of(context).typography;
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
                      onPressed: logic.state.accountInfoLock
                          ? null
                          : () async {
                              if (!logic.state.formKey.currentState!
                                  .validate()) {
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
    final typography = FluentTheme.of(context).typography;
    final color = primaryColor(context);
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

  void _showSelectTimer(BuildContext context) async {
    final typography = FluentTheme.of(context).typography;
    await showDialog(
        barrierDismissible: true,
        context: context,
        builder: (context) => GetBuilder<SyncFileController>(builder: (logic) {
              return ContentDialog(
                  title: Text("自动同步间隔", style: typography.subtitle),
                  content: SizedBox(
                    child: Column(
                      spacing: NFLayout.v2,
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [0, 5, 10, 30, 60]
                          .map((item) => RadioButton(
                              content: Text(item == 0 ? "不启用" : "$item min"),
                              checked: logic.state.timer == item,
                              onChanged: (v) {
                                if (v) {
                                  logic.setTimer(item);
                                }
                              }))
                          .toList(),
                    ),
                  ));
            }));
  }

  @override
  Widget build(BuildContext context) {
    final typography = FluentTheme.of(context).typography;
    final table = GetBuilder<SyncFileController>(builder: (logic) {
      return NFLoadingWidgets(
        loading: logic.state.isLoading,
        child: NFTable(

          empty: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                FluentIcons.cloud_flow,
                size: 60,
                color: typography.body?.color,
              ),
              NFLayout.vlineh1,
              Text("无数据", style: typography.body),
            ],
          ),
          minWidth: 800,
          prototypeItem: NFRow(children: [Text("Some", style: typography.bodyStrong,)]),
          header: [
            NFHeader(flex: 1, child: Text("操作", style: typography.bodyStrong)),
            NFHeader(
                flex: 1, child: Text("本地路径", style: typography.bodyStrong)),
            NFHeader(flex: 1, child: Text("标签", style: typography.bodyStrong)),
            NFHeader(flex: 1, child: Text("状态", style: typography.bodyStrong)),
            NFHeader(
                flex: 1, child: Text("新增 删除 变更", style: typography.bodyStrong))
          ],
          source: _DataSource(logic.state.fileList, logic),
          isCompactMode: true,
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
                  label: const Text("账户"),
                  onPressed: () {
                    _showAccountSetting(context);
                  }),
              CommandBarButton(
                icon: const Icon(FluentIcons.fabric_folder),
                label: const Text("新增"),
                onPressed: () {
                  _showAddSyncDir(context);
                },
              ),
              CommandBarButton(
                  icon: const Icon(FluentIcons.refresh),
                  label: const Text("刷新"),
                  onPressed: logic.state.isLoading
                      ? null
                      : () {
                          logic.refreshList();
                        }),
              CommandBarButton(
                icon: const Icon(FluentIcons.timer),
                label: logic.state.timer == 0
                    ? const Text("不启用")
                    : Text("${logic.state.timer}min"),
                onPressed: () {
                  _showSelectTimer(context);
                },
              )
            ],
          );
        }),
      ),
      content: table,
    );
  }
}

// 数据表格源
class _DataSource extends NFDataTableSource {
  final List<FileMsg> fileList;
  final SyncFileController logic;

  _DataSource(this.fileList, this.logic);

  @override
  NFRow getRow(BuildContext context, int index) {
    final typography = FluentTheme.of(context).typography;
    final file = fileList[index];
    List<Widget> row = [];
    row.add(_buildOperate(context, file));
    row.add(Tooltip(
        message: file.localDir,
        child: Text(
          file.localDir,
          overflow: TextOverflow.ellipsis,
          style: typography.caption,
          maxLines: 2,
        )));
    row.add(Tooltip(
        message: file.tag,
        child: Text(
          file.tag,
          overflow: TextOverflow.ellipsis,
          style: typography.caption,
          maxLines: 2,
        )));
    row.add(() {
      var desc = "";
      switch (file.status) {
        case FileStatusEnumMsg.download:
          desc = "待下载";
          break;
        case FileStatusEnumMsg.synced:
          desc = "已同步";
          break;
        case FileStatusEnumMsg.upload:
          desc = "待上传";
          break;
      }
      return Text(
        desc,
        style: typography.caption,
      );
    }());
    row.add(Text(
      "${file.add}        ${file.del}        ${file.modify}",
      style: typography.caption,
    ));
    return NFRow(children: row);
  }

  @override
  bool get isEmpty => fileList.isEmpty;

  @override
  int? get itemCount => fileList.length;

  Widget _buildOperate(BuildContext context, FileMsg file) {
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
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Button(
            onPressed: file.status == FileStatusEnumMsg.synced
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
  }
}

// 获取一个本地文件夹路径
Future<String?> _addLocalDir() async {
  String? directoryPath = await FilePicker.platform.getDirectoryPath();
  if (directoryPath == null) {
    return null;
  }
  if (Platform.isWindows && !directoryPath.endsWith("\\")) {
    directoryPath += "\\";
  } else if (Platform.isLinux && !directoryPath.endsWith("/")) {
    directoryPath += "/";
  }
  return directoryPath;
}
