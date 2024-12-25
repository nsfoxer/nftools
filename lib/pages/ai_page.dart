
import 'package:fluent_ui/fluent_ui.dart';
import 'package:nftools/api/ai.dart';

class AiPage extends StatelessWidget {
  const AiPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Button(child: Text("ai"), onPressed: () {
        final stream = question("好饿");
        stream.listen( (rsp) {
          debugPrint(rsp.content);
        });
      }),
    );
  }

}