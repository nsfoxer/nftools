import 'package:easy_debounce/easy_debounce.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:get/get.dart';
import 'package:nftools/api/ai.dart' as $api;
import 'package:nftools/utils/log.dart';

import '../state/ai_state.dart';

class AiController extends GetxController {
  final state = AiState();

  @override
  void onReady() {
    _init();
    super.onReady();
  }

  // @override
  // void onClose() {
  //   // state.dispose();
  //   super.dispose();
  // }

  void _init() async {
    // get_kv
    try {
      // 获取KV信息
      final r = await $api.getKV();
      state.appIdController.text = r.apiKey;
      state.secretController.text = r.secret;
    } catch (e) {
      info("未设置KV信息,请先设置");
    }
    update();
  }

  // 设置KV
  Future<bool> setKV() async {
    try {
      await $api.setKV(state.appIdController.text, state.secretController.text);
    } catch (e) {
      return false;
    }
    return true;
  }

  // 请求一次提问
  void quest() {
    if (state.questController.text.isEmpty) {
      return;
    }
    final question = state.questController.text;
    state.contentData.contents.add(question);
    state.contentData.contents.add("");
    state.isLoading = true;
    _quest(question);
    state.questController.clear();
    _jumpBottom();
    update();
  }

  void _jumpBottom() {
    EasyDebounce.debounce("baiduAI_question", const Duration(milliseconds: 50),
        () {
      state.scrollController.animateTo(
          state.scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.ease);
    });
  }

  void _quest(String question) async {
    var stream = $api.quest(question, state.contentData.id);
    stream.listen((data) {
      state.contentData.contents.last += data.content;
      _jumpBottom();
      update();
    }, onDone: () {
      state.isLoading = false;
      update();
    }, onError: (e) {
      if (state.questController.text.isEmpty) {
        state.questController.text = question;
      }
      state.contentData.contents.removeLast();
      state.contentData.contents.removeLast();
      state.isLoading = false;
      update();
    });
  }
}
