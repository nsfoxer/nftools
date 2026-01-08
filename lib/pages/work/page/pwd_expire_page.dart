import 'package:fluent_ui/fluent_ui.dart';
import 'package:get/get.dart';

import '../../../common/style.dart';
import '../controller/pwd_expire_controller.dart';

class PwdExpirePage extends StatelessWidget {
  const PwdExpirePage({super.key});

  @override
  Widget build(BuildContext context) {
    return ScaffoldPage.withPadding(
        header: PageHeader(
          title: Text("密码过期时间重置"),
        ),
        content: Row(
          children: [
            Expanded(flex: 1, child: Container()),
            Expanded(flex: 3, child: _buildContent(context)),
            Expanded(flex: 1, child: Container()),
          ],
        ));
  }

  Widget _buildContent(BuildContext context) {
    return GetBuilder<PwdExpireController>(builder: (logic) {
      return Column(
          spacing: NFLayout.v1,
          children: [
        InfoLabel(
          label: "账户id",
          child: TextFormBox(
            controller: logic.accountIdController,
            placeholder: "请输入账户id",
          ),
        ),
        FilledButton(
            onPressed: logic.resetPwdExpireTime,
            child: Text("重置密码过期时间")),
      ]);
    });
  }
}
