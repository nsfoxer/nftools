import 'package:fluent_ui/fluent_ui.dart';

import '../../../utils/log.dart';

class TestPage extends StatelessWidget {
  const TestPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(children: [NFRect(rect: Rect.fromLTWH(30, 30, 200, 100))]);
  }
}

class NFRect extends StatefulWidget {
  final Rect rect;

  const NFRect({super.key, required this.rect});

  @override
  State<NFRect> createState() {
    return _NFRectState();
  }
}

class _NFRectState extends State<NFRect> {
  final _margin = 10.0;
  final _dot = 20.0;
  final _borderWidth = 2.0;
  late Rect _currentRect;
  late Rect _topRect;
  late Rect _leftRect;
  _OperationDirectionEnum? _directionEnum;

  @override
  void initState() {
    super.initState();
    _currentRect = widget.rect;
  }

  @override
  Widget build(BuildContext context) {
    final offset = _borderWidth / 2;
    _topRect = Rect.fromCenter(
        center: Offset(_margin + _currentRect.width / 2, _margin + offset),
        width: _dot,
        height: _dot);
    _leftRect = Rect.fromCenter(
        center: Offset(_margin + offset, _margin+_currentRect.height / 2),
        width: _dot,
        height: _dot);
    return Positioned(
        top: _currentRect.top,
        left: _currentRect.left,
        child: GestureDetector(
            onPanStart: _handlePanStart,
            onPanEnd: _handlePanEnd,
            onPanUpdate: _handlePanUpdate,
            child: Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                Container(
                    margin: EdgeInsets.all(_margin),
                    width: _currentRect.width,
                    height: _currentRect.height,
                    decoration: BoxDecoration(
                        border:
                            Border.all(color: Colors.red, width: _borderWidth)),
                    ),
                Positioned(
                  top: _topRect.top,
                  left: _topRect.left,
                  width: _topRect.width,
                  height: _topRect.height,
                  child: Container(color: Colors.blue),
                ),
                Positioned(
                  left: _leftRect.left,
                  top: _leftRect.top,
                  child: Container(
                    width: _dot,
                    height: _dot,
                    color: Colors.blue,
                  ),
                ),
              ],
            )));
  }

  void _handlePanStart(DragStartDetails details) {
    if (_topRect.contains(details.localPosition)) {
      _directionEnum = _OperationDirectionEnum.top;
    } else if (_leftRect.contains(details.localPosition)) {
      debug("left");
      _directionEnum = _OperationDirectionEnum.left;
    } else {
      _directionEnum = null;
    }
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    if (_directionEnum == _OperationDirectionEnum.top && _directionEnum == _OperationDirectionEnum.top) {
    } else if (_leftRect.contains(details.localPosition) && _directionEnum == _OperationDirectionEnum.left) {
      _currentRect = Rect.fromLTWH(
          details.localPosition.dx,
          _currentRect.top,
          _currentRect.width - details.localPosition.dx + _currentRect.left,
          _currentRect.height);
      debug("left update");
      setState(() {});
    }
  }

  void _handlePanEnd(DragEndDetails details) {
    debug("end");
    debug("${_leftRect.contains(details.localPosition)}");
    if (_topRect.contains(details.localPosition) &&
        _directionEnum == _OperationDirectionEnum.top) {
    } else if ( _leftRect.contains(details.localPosition) &&
        _directionEnum == _OperationDirectionEnum.left) {
      _currentRect = Rect.fromLTWH(
          details.localPosition.dx,
          _currentRect.top,
          _currentRect.width - details.localPosition.dx + _currentRect.left,
          _currentRect.height);
      debug("left end");
      setState(() {});
    } else {
      _directionEnum = null;
    }
  }
}

enum _OperationDirectionEnum { top, left, right, bottom }
