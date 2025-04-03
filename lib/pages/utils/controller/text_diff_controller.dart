import 'package:easy_debounce/easy_throttle.dart';
import 'package:get/get.dart';
import 'package:nftools/common/constants.dart';

import '../state/text_diff_state.dart';


class TextDiffController extends GetxController {

 final TextDiffState state = TextDiffState();


 @override
 void onInit() {
    super.onInit();
    state.oldTextEditingController.addListener(_updateDiff);
    state.newTextEditingController.addListener(_updateDiff);
 }

 void _updateDiff(){
   EasyThrottle.throttle(PageWidgetNameConstant.textDiffTextPrettyDiffText, const Duration(seconds: 1), () {
     update([PageWidgetNameConstant.textDiffTextPrettyDiffText]);
   });
 }

 @override
  void onClose() {
    super.onClose();
    state.oldTextEditingController.dispose();
    state.newTextEditingController.dispose();
  }

}