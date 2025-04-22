import 'package:easy_debounce/easy_debounce.dart';
import 'package:get/get.dart';
import 'package:nftools/common/constants.dart';
import 'package:nftools/pages/utils/state/text_tool_state.dart';

import '../state/text_diff_state.dart';


class TextToolController extends GetxController {

 final TextToolState state = TextToolState();

 @override
 void onInit() {
    super.onInit();
    state.textEditingController.addListener(_updateDiff);

    for (var i = 0; i < 10; i++) {
      state.data.add((i.toString(), (i*100).toString()));
    }

 }

 void _updateDiff(){
   EasyDebounce.debounce(PageWidgetNameConstant.textDiffTextPrettyDiffText, const Duration(milliseconds: 500), () {
     update([PageWidgetNameConstant.textDiffTextPrettyDiffText]);
   });
 }

 @override
  void onClose() {
    super.onClose();
    state.textEditingController.dispose();
  }

  void operate(TextToolEnum textToolEnum){

  }

}

enum TextToolEnum {
  sortAsc("排序"),
  sortDesc("排序（降序）"),
  unique("去重");

  const TextToolEnum(this.desc);

  final String desc;
}