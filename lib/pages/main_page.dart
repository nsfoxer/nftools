import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:nftools/api/display_api.dart';
import 'package:nftools/utils/time.dart';
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

  void _initData() {
    var delay = measureDelay(() async {
      desc = await displaySupport();
      setState(() {
      });
    });
    $message.info(message: "耗时${delay.inMicroseconds}us");
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      child: Center(
        child: TolyAction(
          child: Icon(CupertinoIcons.info),
          onTap: () {
            _initData();
          },
        ),
      ),
    );
  }
}
