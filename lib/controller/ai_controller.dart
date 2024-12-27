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
    await _initQuestionIdList();
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
    state.contentData.contents.insert(0, question);
    state.contentData.contents.insert(0, "");
    state.isLoading = true;
    _quest(question);
    state.questController.clear();
    _jumpBottom();
    update();
  }

  void _jumpBottom() {
    EasyDebounce.debounce("baiduAI_question", const Duration(milliseconds: 50),
        () {
      state.scrollController.animateTo(0.0,
          duration: const Duration(milliseconds: 300), curve: Curves.ease);
    });
  }

  void _quest(String question) async {
    var stream = $api.quest(question, state.contentData.id);
    stream.listen((data) {
      state.contentData.contents.first += data.content;
      _jumpBottom();
      update();
    }, onDone: () {
      if (state.contentData.description.isEmpty) {
        final desc = _subDesc(question);
        state.contentData.description = desc;
        state.idList.last = (state.contentData.id, desc);
      }
      state.isLoading = false;
      update();
    }, onError: (e) {
      if (state.questController.text.isEmpty) {
        state.questController.text = question;
      }
      state.contentData.contents.removeAt(0);
      state.contentData.contents.removeAt(0);
      state.isLoading = false;
      update();
    }, cancelOnError: true);
  }

  // 初始化问题列表
  Future<void> _initQuestionIdList() async {
    var result = await $api.getQuestionList();
    result.sort((x, y) {
      return x.id.compareTo(y.id);
    });
    state.idList = result.map((x) {
      return (x.id, _subDesc(x.desc));
    }).toList();
    if (state.idList.isEmpty) {
      state.contentData = AiContentData(0, "", []);
    } else {
      await selectQuestionId(state.idList.last.$1, nUpdate: false);
    }
  }

  Future<void> selectQuestionId(int id, {bool nUpdate = true}) async {
    debugPrint("${state.idList}");
    var contents = await $api.getQuestion(id);
    contents = contents.reversed.toList();
    debugPrint("$contents");
    if (contents.isEmpty) {
      state.contentData = AiContentData(id, "", []);
    } else {
      state.contentData = AiContentData(id, contents.last, contents);
    }

    if (nUpdate) {
      update();
    }
  }

  void addQuestionId() async {
    state.questController.clear();
    int id;
    if (state.idList.isEmpty) {
      id = 0;
    } else if (state.contentData.contents.isNotEmpty) {
      id = state.idList.last.$1 + 1;
    } else if (state.idList.last.$2.isNotEmpty) {
      id = state.idList.last.$1;
    } else {
      return;
    }
    await $api.addQuestion(id);
    state.idList.add((id, ""));
    state.contentData = AiContentData(id, "", []);
    update();
  }

  String _subDesc(String desc) {
    if (desc.length > 15) {
      return desc.substring(0, 15);
    }
    return desc;
  }
}
