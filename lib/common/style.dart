import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

final class NFTextStyle {
  static const TextStyle h1 =
      TextStyle(fontSize: 28, fontWeight: FontWeight.bold);
  static const TextStyle h2 =
      TextStyle(fontSize: 24, fontWeight: FontWeight.w500);

  static const TextStyle p1 =
      TextStyle(fontSize: 16, fontWeight: FontWeight.w500);
  static const TextStyle p2 =
      TextStyle(fontSize: 14, fontWeight: FontWeight.w500);
  static const TextStyle p3 =
      TextStyle(fontSize: 12, fontWeight: FontWeight.w500);
}

final class NFLayout {
  static const double v0 = 10.0;
  static const double v1 = 8.0;
  static const double v2 = 6.0;
  static const double v3 = 4.0;
  static const SizedBox vlineh1 = SizedBox(height: v1);
  static const SizedBox vlineh2 = SizedBox(height: v2);
  static const SizedBox vlineh3 = SizedBox(height: v3);

  static const SizedBox hlineh1 = SizedBox(width: v1);
  static const SizedBox hlineh2 = SizedBox(width: v2);
  static const SizedBox hlineh3 = SizedBox(width: v3);
}

final class NFColor {
  static const Color textUserLightBackground = Color(0xff95ec69);
  static const Color textUserDarkBackground = Color(0xff3eb575);
}