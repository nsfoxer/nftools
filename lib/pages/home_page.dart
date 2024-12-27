
import 'package:fluent_ui/fluent_ui.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    var typography = FluentTheme.of(context).typography;
    return ScaffoldPage(
      header: PageHeader(
        title: Text("主页"),
      ),
      content: Center(
        child: Text("nftools", style: typography.title,),
      ),
    );
  }
  
}