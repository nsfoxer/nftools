import 'package:data_table_2/data_table_2.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/material.dart' as $me;
import 'package:get/get.dart';
import 'package:nftools/controller/sync_file_controller.dart';
import 'package:nftools/utils/nf-widgets.dart';

import '../messages/syncfile.pb.dart';

class SyncFilePage extends StatelessWidget {
  const SyncFilePage({super.key});

  @override
  Widget build(BuildContext context) {
    var typography = FluentTheme.of(context).typography;
    var table = GetBuilder<SyncFileController>(builder: (logic) {
      return LoadingWidgets(
          loading: logic.state.isLoading,
          child: PaginatedDataTable2(
            rowsPerPage: 10,
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
      header: const PageHeader(
        title: Text("文件同步"),
      ),
      content: table,
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
