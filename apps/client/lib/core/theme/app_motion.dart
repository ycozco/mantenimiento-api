import 'package:flutter/material.dart';

abstract final class AppMotion {
  static const curve = Curves.easeOutCubic;

  static Duration duration(BuildContext context) =>
      MediaQuery.disableAnimationsOf(context)
      ? Duration.zero
      : const Duration(milliseconds: 220);
}
