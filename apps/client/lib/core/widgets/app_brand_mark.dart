import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Transparent vector mark: the surrounding surface belongs to the caller.
class AppBrandMark extends StatelessWidget {
  const AppBrandMark({super.key, this.size = 36});

  final double size;

  @override
  Widget build(BuildContext context) => SvgPicture.asset(
    'assets/brand/decolumax_mark.svg',
    width: size,
    height: size,
    semanticsLabel: 'Decolumax',
  );
}
