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
  @override
  void dispose() {
    state.dispose();
    super.dispose();
  }

  void _init() async {
    // get_kv
    try {
      final r = await $api.getKV();
      state.appIdController.text = r.apiKey;
      state.secretController.text = r.secret;
    } catch (e) {
      info("未设置KV信息,请先设置");
    }

    update();
  }

  Future<bool> setKV() async {
    try {
      await $api.setKV(state.appIdController.text, state.secretController.text);
    } catch (e) {
      return false;
    }
    return true;
  }

  void quest() {
    if (state.questController.text.isEmpty) {
      return;
    }
    final question = state.questController.text;
    _quest(question);
    state.questController.clear();
    update();
  }

  void _quest(String question) async {
   var stream = $api.quest(question);
   stream.listen((data) {
     state.displayController.text += data.content;
     update();
   });
  }

}