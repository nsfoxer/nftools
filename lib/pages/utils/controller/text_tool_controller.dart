import 'dart:convert';

import 'package:get/get.dart';
import 'package:nftools/common/constants.dart';
import 'package:nftools/pages/utils/state/text_tool_state.dart';
import 'package:nftools/utils/log.dart';
import 'package:pasteboard/pasteboard.dart';

class TextToolController extends GetxController {

 final TextToolState state = TextToolState();
 final JsonDecoder _jsonDecoder = const JsonDecoder();
 final JsonEncoder _jsonPrettyEncoder = const JsonEncoder.withIndent('  ');


 @override
  void onClose() {
    state.textEditingController.dispose();
    super.onClose();
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
      case TextToolEnum.json:
        _jsonFormat(false); break;
      case TextToolEnum.miniJson:
        _jsonFormat(true); break;
      case TextToolEnum.clean:
        _cleanInvisibleCharacters(state.textEditingController.text);
        break;
    }

    update([PageWidgetNameConstant.textToolPageStatistic]);
  }

  void _cleanInvisibleCharacters(String input) {
    // 匹配 ASCII 码范围在 0 - 31 以及 127 的不可见字符
    RegExp invisibleChars = RegExp(r'[\x00-\x09\x0B-\x1F\x7F\xa0]');
    state.textEditingController.text = input.replaceAll(invisibleChars, '');
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

  void _jsonFormat(bool isMini){
    dynamic data;
    try {
     data = _jsonDecoder.convert(state.textEditingController.text);
     // 打印data的类型
     info("data类型: ${data.runtimeType}");
    } catch (e) {
      error("JSON格式错误\n ${e.toString()}");
      return;
    }
    final String result;
    if (isMini) {
      result = json.encode(data);
    } else {
      result = _jsonPrettyEncoder.convert(data);
    }
    state.textEditingController.text = result;

    // 统计
    state.data = [];

    update([PageWidgetNameConstant.textToolPageStatistic]);
  }


}

enum TextToolEnum {
  sortAsc("排序"),
  sortDesc("排序（降序）"),
  unique("去重"),
  json("JSON格式化"),
  miniJson("JSON格式化（最小化）"),
  clean("清除非正常字符"),
  ;

  const TextToolEnum(this.desc);

  final String desc;
}