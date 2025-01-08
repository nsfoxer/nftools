import 'package:easy_debounce/easy_debounce.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:get/get.dart';
import 'package:nftools/api/ai.dart' as $api;
import 'package:nftools/messages/ai.pb.dart';

import '../state/ai_state.dart';

class AiController extends GetxController {
  final state = AiState();

  @override
  void onReady() {
    _init();
    super.onReady();
  }

  @override
  void onClose() {
    state.dispose();
  }

  void _init({bool forceUpdate = false}) async {
    // get_kv
    try {
      final model = await $api.getModel();
      state.modelEnum = model;
      // 获取KV信息
      final r = await $api.getKV();
      state.appIdController.text = r.apiKey;
      state.secretController.text = r.secret;
      if (state.modelEnum == ModelEnum.Baidu && r.apiKey.isNotEmpty && r.secret.isNotEmpty) {
        state.isLogin = true;
      }
      if (state.modelEnum == ModelEnum.Spark && r.apiKey.isNotEmpty) {
        state.isLogin = true;
      }
    } catch (e) {
      if (forceUpdate) {
        update();
      }
      return;
    }
    await _initQuestionIdList();
    update();
    return;
  }

  // 设置KV
  Future<bool> setKV() async {
    try {
      await $api.setKV(state.appIdController.text, state.secretController.text);
    } catch (e) {
      return false;
    }
    state.isLogin = true;
    update();
    return true;
  }

  // 请求一次提问
  void quest() {
    final question = state.questController.text.trim();
    state.questController.text = question;
    if (question.isEmpty) {
      return;
    }
    state.contentData.contents.insert(0, question);
    state.contentData.contents.insert(0, "");
    state.isLoading = true;
    _quest(question);
    state.questController.clear();
    _jumpBottom(true);
    update();
  }

  void _jumpBottom(bool ignoreOffset) {
    EasyDebounce.debounce("baiduAI_question", const Duration(milliseconds: 50),
        () {
      if (state.scrollController.positions.isEmpty) {
        return;
      }
      if (!ignoreOffset && state.scrollController.offset > 300) {
        return;
      }
      state.scrollController.animateTo(0.0,
          duration: const Duration(milliseconds: 300), curve: Curves.ease);
    });
  }

  void _quest(String question) async {
    var stream = $api.quest(question, state.contentData.id);
    stream.listen((data) {
      state.contentData.contents.first += data.content;
      _jumpBottom(false);
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
      return (x.id, x.desc);
    }).toList();
    if (state.idList.isEmpty) {
      state.contentData = AiContentData(0, "", []);
    } else {
      await selectQuestionId(state.idList.last.$1, nUpdate: false);
    }
  }

  Future<void> selectQuestionId(int id, {bool nUpdate = true}) async {
    var contents = await $api.getQuestion(id);
    contents = contents.reversed.toList();
    if (contents.isEmpty) {
      state.contentData = AiContentData(id, "", []);
    } else {
      state.contentData = AiContentData(id, contents.last, contents);
    }

    if (nUpdate) {
      update();
    }
  }

  Future<void> addQuestionId() async {
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
    if (desc.length > 8) {
      return desc.substring(0, 8);
    }
    return desc;
  }

  Future<void> deleteQuestionId(int id) async {
    await $api.delQuestion(id);
    if (id != state.contentData.id) {
      state.idList.removeWhere((x) => x.$1 == id);
    } else {
      await _initQuestionIdList();
    }
    update();
  }

  Future<void> changeModel() async {
    final ModelEnum model;
    if (state.modelEnum == ModelEnum.Baidu) {
      model = ModelEnum.Spark;
    } else {
      model = ModelEnum.Baidu;
    }
    state.reInit();
    state.modelEnum = model;
    await $api.setModel(model);
    _init(forceUpdate: true);
  }
}
