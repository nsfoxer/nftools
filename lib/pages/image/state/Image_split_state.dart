
import 'package:fluent_ui/fluent_ui.dart';
import 'package:nftools/utils/nf_widgets.dart';

class ImageSplitState {
  bool isLoading = false;
  // 原始图片
  String? originalImage;

  // 当前图片
  String? currentImage;

  // 分割结果图片
  String? resultImage;

  // 当前分割步骤
  int step = 0;

  // 控制器
  NFImagePainterController controller = NFImagePainterController(DrawType.none, 0, Colors.transparent, null);


  void reset() {
    originalImage = null;
    currentImage = null;
    resultImage = null;
    step = 0;
    controller.reset();
    isLoading = false;
  }

}