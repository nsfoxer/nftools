import 'package:fluent_ui/fluent_ui.dart';
import 'package:get/get.dart';

import '../controller/image_split_controller.dart';

class ImageSplitPage extends StatelessWidget {
  const ImageSplitPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ScaffoldPage.withPadding(
      header: PageHeader(
          title: const Text("前景分割"),
          commandBar: GetBuilder<ImageSplitController>(
            builder: (logic) => CommandBar(
                mainAxisAlignment: MainAxisAlignment.end,
                primaryItems: [
                  CommandBarButton(
                    icon: Icon(FluentIcons.next),
                    label: Text("下一步"),
                    onPressed: () {},
                  ),
                  CommandBarButton(
                      icon: Icon(FluentIcons.clear),
                      label: Text("重置"),
                      onPressed: () {}),
                ]),
          )),
      content: Center(
        child: Text("ImageSplitPage"),
      ),
    );
  }
}
