import 'package:flutter/material.dart';

/// Cuts the top-left and top-right corners to recreate the classic
/// Philippine LTO temporary motorcycle plate shape.
class IrregularHexagonClipper extends CustomClipper<Path> {
  final double cutSize;

  IrregularHexagonClipper({this.cutSize = 28.0});

  @override
  Path getClip(Size size) {
    final path = Path();
    // Start at top-left cut point
    path.moveTo(cutSize, 0);
    // Across top edge to top-right cut point
    path.lineTo(size.width - cutSize, 0);
    // Down slope to top-right edge
    path.lineTo(size.width, cutSize);
    // Down right side to bottom-right corner
    path.lineTo(size.width, size.height);
    // Across bottom edge to bottom-left corner
    path.lineTo(0, size.height);
    // Up left side to top-left cut edge
    path.lineTo(0, cutSize);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
