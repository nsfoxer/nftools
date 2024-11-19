import 'package:data_table_2/data_table_2.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/material.dart' as $me;

class SyncFilePage extends StatelessWidget {
  SyncFilePage({super.key});

  $me.DataTableSource _sourceData = SourceData();

  @override
  Widget build(BuildContext context) {
    var typography = FluentTheme.of(context).typography;
    var table = PaginatedDataTable2(
      // border: const TableBorder(),
      rowsPerPage: 10,
      onPageChanged: (page) {},
      columns: [
        DataColumn2(label: Text("本地", style: typography.bodyStrong)),
        DataColumn2(label: Text("远端", style: typography.bodyStrong)),
        DataColumn2(label: Text("状态", style: typography.bodyStrong)),
        DataColumn2(label: Text("操作", style: typography.bodyStrong)),
      ],
      source: _sourceData,
    );
    return ScaffoldPage(
      header: const PageHeader(
        title: Text("文件同步"),
      ),
      content: table,
    );
  }
}

class SourceData extends $me.DataTableSource {
  @override
  $me.DataRow? getRow(int index) {
    return DataRow2(cells: [
      $me.DataCell(Text(index.toString())),
      $me.DataCell(Text(index.toString())),
      $me.DataCell(Text(index.toString())),
      $me.DataCell(Text(index.toString())),
    ]);
  }

  @override
  bool get isRowCountApproximate => false;

  @override
  int get rowCount => 10;

  @override
  int get selectedRowCount => 0;
}
