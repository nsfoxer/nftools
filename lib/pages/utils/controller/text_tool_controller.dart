import 'package:easy_debounce/easy_debounce.dart';
import 'package:get/get.dart';
import 'package:nftools/common/constants.dart';
import 'package:nftools/pages/utils/state/text_tool_state.dart';
import 'package:nftools/utils/log.dart';
import 'package:pasteboard/pasteboard.dart';

import '../state/text_diff_state.dart';


class TextToolController extends GetxController {

 final TextToolState state = TextToolState();

 @override
 void onInit() {
    super.onInit();
    state.textEditingController.addListener(_updateDiff);
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
    switch (textToolEnum) {
      case TextToolEnum.sortAsc:
        state.data = _sort(true);
        break;
      case TextToolEnum.sortDesc:
        state.data = _sort(false);
        break;
      case TextToolEnum.unique:
        state.data = _unique();
        break;
    }

    update([PageWidgetNameConstant.textToolPageStatistic]);
  }

  // 排序
  List<(String, String)> _sort(bool isAsc){
    final data = _baseFilterText(state.textEditingController.text);
    data.sort((a, b) => isAsc? a.compareTo(b) : b.compareTo(a));
    state.textEditingController.text = data.join('\n');
    return _baseStatisticText(data);
  }

  // 基本过滤Text
  List<String> _baseFilterText(String text) {
    return text
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
  }

  List<(String, String)> _baseStatisticText(List<String> data) {
    // 统计每一行数据的出现次数
    Map<String, int> lineCount = {};
    for (String line in data) {
      lineCount[line] = (lineCount[line] ?? 0) + 1;
    }
    // 对结果按出现次数排序
    List<MapEntry<String, int>> sortedResult = lineCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // 返回统计数据
    List<(String, String)> result = [("数据", "出现次数/次")];
    for (MapEntry<String, int> entry in sortedResult) {
      result.add((entry.key, entry.value.toString()));
    }
    return result;
  }

  // 去重排序
  List<(String, String)> _unique(){
    final data = _baseFilterText(state.textEditingController.text);
    final statisticData = _baseStatisticText(data);

    // 保存text数据
    final resultString = statisticData.skip(1).map((e) => e.$1).join('\n');
    state.textEditingController.text = resultString;

    return statisticData;
  }

  // 复制统计数据
  void copyData() {
    if (state.data.isEmpty) {
      return;
    }
    final data = state.data.map((x) => "${x.$1}\t${x.$2}").join('\n');
    Pasteboard.writeText(data);
    info("复制统计成功");
  }

}

enum TextToolEnum {
  sortAsc("排序"),
  sortDesc("排序（降序）"),
  unique("去重");

  const TextToolEnum(this.desc);

  final String desc;
}