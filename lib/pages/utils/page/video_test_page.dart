
import 'package:fluent_ui/fluent_ui.dart';
import 'package:get/get_state_manager/src/simple/get_state.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:nftools/pages/utils/controller/video_test_controller.dart';

class VideoTestPage extends StatelessWidget {
  const VideoTestPage({super.key});


  @override
  Widget build(BuildContext context) {
    // _player.open(
    //   Media("file://C:/Users/12618/Videos/untitled.mp4")
    // );
    return ScaffoldPage.withPadding(
      header: const PageHeader(title: Text("video test")),
      content: Center(
        child: GetBuilder<VideoTestController>(
          builder: (logic) {
            if (logic.controller == null) {
              return const Text("loading");
            }
            return Video(
              controller: logic.controller!,
            );
          },
        )
      ),
    );
  }

}