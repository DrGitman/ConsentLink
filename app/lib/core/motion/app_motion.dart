import 'package:flutter/material.dart';

abstract final class AppMotion {
  static const fast = Duration(milliseconds: 150);
  static const base = Duration(milliseconds: 250);
  static const slow = Duration(milliseconds: 400);
  static const reduced = Duration(milliseconds: 200);

  static const fastCurve = Curves.easeOut;
  static const baseCurve = Curves.easeOutCubic;
  static const slowCurve = Curves.easeInOutCubic;
}
