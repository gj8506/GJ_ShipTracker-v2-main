import 'package:flutter/material.dart';
import '../constants/app_constants.dart';
import '../theme/app_colors.dart';

class AppLogo extends StatelessWidget {
  final double size;
  final bool circular;
  final Color? borderColor;
  final double borderWidth;

  const AppLogo({
    super.key,
    this.size = 72,
    this.circular = true,
    this.borderColor,
    this.borderWidth = 2.0,
  });

  @override
  Widget build(BuildContext context) {
    Widget image = Image.asset(
      AppConstants.logoAsset,
      width: size,
      height: size,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          width: size,
          height: size,
          color: AppColors.surfaceVariant,
          child: Icon(
            Icons.broken_image,
            size: size * 0.45,
            color: AppColors.textSecondary,
          ),
        );
      },
    );

    if (circular) {
      image = ClipOval(child: image);
    } else {
      image = ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: image,
      );
    }

    if (borderColor != null) {
      image = Container(
        decoration: BoxDecoration(
          shape: circular ? BoxShape.circle : BoxShape.rectangle,
          borderRadius: circular ? null : BorderRadius.circular(12),
          border: Border.all(color: borderColor!, width: borderWidth),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: image,
      );
    }

    return image;
  }
}
