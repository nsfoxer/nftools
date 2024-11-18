import 'package:data_table_2/data_table_2.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/material.dart' as $me;

class SyncFilePage extends StatelessWidget {
  const SyncFilePage({super.key});

  @override
  Widget build(BuildContext context) {
    var color =
        FluentTheme.of(context).resources.solidBackgroundFillColorTertiary;
    return ScaffoldPage(
      header: PageHeader(
        title: const Text("文件同步"),
      ),
      content: $me.Scaffold(
        backgroundColor: color,
        body:
      DataTable2(
          columnSpacing: 12,
          horizontalMargin: 12,
          minWidth: 600,
          columns: [
            DataColumn2(
              label: Text('Column A'),
              size: ColumnSize.L,
            ),
            DataColumn2(
              label: Text('Column B'),
            ),
            DataColumn2(
              label: Text('Column C'),
            ),
            DataColumn2(
              label: Text('Column D'),
            ),
            DataColumn2(
              label: Text('Column NUMBERS'),
              numeric: true,
            ),
          ],
          rows: List<$me.DataRow>.generate(
              100,
              (index) => $me.DataRow(cells: [
                    $me.DataCell(Text('A' * (10 - index % 10))),
                    $me.DataCell(Text('B' * (10 - (index + 5) % 10))),
                    $me.DataCell(Text('C' * (15 - (index + 5) % 10))),
                    $me.DataCell(Text('D' * (15 - (index + 10) % 10))),
                    $me.DataCell(Text(((index + 0.1) * 25.4).toString()))
                  ]))),
    ));
  }
}
