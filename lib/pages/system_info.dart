import 'dart:async';
import 'dart:math';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:graphic/graphic.dart';
import 'package:nftools/utils/log.dart';

class SystemInfoPage extends StatefulWidget {
  @override
  State<StatefulWidget> createState() {
    return SystemInfoPageState();
  }
}

class SystemInfoPageState extends State<SystemInfoPage> {
  List<Map<dynamic, dynamic>> datas = [];
  late Timer timer;
  final rdm = Random();

  final priceVolumeStream = StreamController<GestureEvent>.broadcast();

  @override
  void initState() {
    datas = [
      {'genre': 0.toString(), 'sold': rdm.nextInt(100)},
      {'genre': 1.toString(), 'sold': rdm.nextInt(100)},
    ];

    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        info("message");
        datas = [
          {'genre': 0.toString(), 'sold': rdm.nextInt(100)},
          {'genre': 1.toString(), 'sold': rdm.nextInt(100)},
        ];
      });
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Chart(
      rebuild: false,
      data: datas,
      variables: {
        'genre': Variable(
          accessor: (Map map) => map['genre'] as String,
        ),
        'sold': Variable(
          accessor: (Map map) => map['sold'] as num,
          scale: LinearScale(max: 100, min: 0),
        ),
      },
      marks: [
        AreaMark(
          shape: ShapeEncode(value: BasicAreaShape(smooth: true)),
          color: ColorEncode(
              value: FluentTheme.of(context).accentColor.withAlpha(80)),
        ),
        LineMark(
          shape: ShapeEncode(value: BasicLineShape(smooth: true)),
          size: SizeEncode(value: 0.3),
        ),
      ],
      axes: [
        Defaults.horizontalAxis
        ..grid = Defaults.strokeStyle,
        Defaults.verticalAxis
        ..line = Defaults.strokeStyle,
      ],
    );
  }
}
