import 'package:fluent_ui/fluent_ui.dart';

class SyncFilePage extends StatelessWidget {
  const SyncFilePage({super.key});

  @override
  Widget build(BuildContext context) {
    var color = FluentTheme.of(context).resources.solidBackgroundFillColorTertiary;
    var typography = FluentTheme.of(context).typography;
    return ScaffoldPage(
      header: const PageHeader(
        title: Text("文件同步"),
      ),
      content:ListView.builder(
          itemCount: 10,
          itemBuilder: (context, index) {
            return ListTile.selectable(
              title: Text("aaa"),
            );
          }
      ),
    );
  }
}
