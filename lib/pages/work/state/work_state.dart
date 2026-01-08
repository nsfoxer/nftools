import 'package:fluent_ui/fluent_ui.dart';

class WorkState {

  GlobalKey<FormState> formKey = GlobalKey();

  bool isConfigPage = true;

  TextEditingController urlTextController = TextEditingController();
  TextEditingController keyTextController = TextEditingController();
  TextEditingController tokenTextController = TextEditingController();

}
