import 'package:flutter/cupertino.dart';
import 'package:tolyui/basic/button/toly_action.dart';
import 'package:tolyui/tolyui.dart';

class MainPage extends StatefulWidget {
  const MainPage({Key? key}) : super(key: key);

  @override
  _MainPageState createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  bool desc = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      child: Center(
        child: TolyAction(
          child: Icon(CupertinoIcons.info),
          onTap: () {},
        ),
      ),
    );
  }
}
