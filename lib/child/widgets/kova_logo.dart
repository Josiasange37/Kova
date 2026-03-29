import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class KovaLogo extends StatelessWidget {
  final double width;
  final double height;
  final Color color;

  const KovaLogo({
    super.key,
    this.width = 145,
    this.height = 115,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'assets/svg/kova_logo.svg',
      width: width,
      height: height,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
    );
  }
}
