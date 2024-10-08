import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:nftools/controller/MainPageController.dart';
import 'package:tolyui/basic/button/toly_action.dart';
import 'package:tolyui/tolyui.dart';

import '../common/style.dart';
import '../utils/nf-widgets.dart';

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
    return SingleChildScrollView(
        child: Padding(
            padding: EdgeInsets.all(NFLayout.v1),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "主页",
                  style: NFTextStyle.h1,
                ),
                NFLayout.vlineh1,
                Text(
                  "显示器亮度",
                  style: NFTextStyle.h2,
                ),
                NFLayout.vlineh2,
                NFCard(
                    child: SizedBox(
                  height: 100.0,
                  child: Center(
                    child: Text("center"),
                  ),
                ))
              ],
            )));
  }
}


