import 'dart:io';
import 'dart:math' as math;

import 'package:fluent_ui/fluent_ui.dart';

import '../../../utils/nf_widgets.dart';

class TestPage extends StatelessWidget {

  const TestPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ScaffoldPage.withPadding(
        header: PageHeader(title: const Text("测试")),
        content:
          StaggerRoute(),

    );
  }
}

class StaggerAnimation extends StatelessWidget {
  late final Animation<double> controller;
  late final Animation<double> height;
  late final Animation<Color?> color;
  late final Animation<EdgeInsets> padding;


  StaggerAnimation({
    Key? key,
    required this.controller,
  }) : super(key: key) {
    height = Tween<double>(begin: 0.0, end: 300.0).animate(
      CurvedAnimation(parent: controller, curve: Interval(0.0, 0.6, curve: Curves.ease))
    );
    color = ColorTween(begin: Colors.green, end: Colors.red).animate(
      CurvedAnimation(parent: controller, curve: Interval(0.6, 1.0, curve: Curves.ease))
    );
    padding = Tween<EdgeInsets>(begin: EdgeInsets.only(left: 0.0), end: EdgeInsets.only(left: 200.0)).animate(
      CurvedAnimation(parent: controller, curve: Interval(0.0, 1.0, curve: Curves.ease))
    );
  }

  Widget _buildAnimation(BuildContext context, child) {
    return Container(
      alignment: Alignment.bottomLeft,
      padding: padding.value,
      child: Container(
        height: height.value,
        width: 50.0,
        color: color.value,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: _buildAnimation,
    );
  }
}

class StaggerRoute extends StatefulWidget {
  @override
  State<StaggerRoute> createState() => _StaggerRouteState();
}

class _StaggerRouteState extends State<StaggerRoute> with TickerProviderStateMixin{
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
  }

  void _playAnimation() async{
    try {
      await _controller.forward().orCancel;
      await _controller.reverse().orCancel;
    } on TickerCanceled {
      // the animation got canceled, probably because we were disposed
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Button(
          onPressed: () => _playAnimation(),
          child: const Text('Start Animation'),
        ),
        Container(
          height: 300,
          width: 300,
          decoration: BoxDecoration(
            border: Border.all(
              color: Colors.black,
              width: 2.0,
            ),
          ),
          child: StaggerAnimation(controller: _controller),
        ),
      ],
    );
  }
}