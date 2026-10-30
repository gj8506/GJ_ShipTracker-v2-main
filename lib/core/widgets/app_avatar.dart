import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class AppAvatar extends StatelessWidget {
  final String? name;
  final String? displayName;
  final String? photoUrl;
  final double radius;
  final double? size;

  const AppAvatar({
    super.key,
    this.name,
    this.displayName,
    this.photoUrl,
    this.radius = 24,
    this.size,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveRadius = size != null ? size! / 2 : radius;
    final effectiveName = displayName ?? name;

    if (photoUrl != null && photoUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: effectiveRadius,
        backgroundImage: NetworkImage(photoUrl!),
      );
    }

    final initial = (effectiveName != null && effectiveName.isNotEmpty)
        ? effectiveName[0].toUpperCase()
        : 'U';

    return CircleAvatar(
      radius: effectiveRadius,
      backgroundColor: AppColors.tealContainer,
      child: Text(
        initial,
        style: TextStyle(
          color: AppColors.tealAccent,
          fontWeight: FontWeight.bold,
          fontSize: effectiveRadius * 0.8,
        ),
      ),
    );
  }
}

class AppLogo extends StatelessWidget {
  final double size;
  final bool showText;

  const AppLogo({
    super.key,
    this.size = 48,
    this.showText = true,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.navyPrimary, AppColors.navySecondary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(size * 0.28),
          ),
          child: Center(
            child: Icon(
              Icons.local_shipping_rounded,
              color: AppColors.tealAccent,
              size: size * 0.55,
            ),
          ),
        ),
        if (showText) ...[
          const SizedBox(width: 12),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'GJandAsher',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.navyPrimary,
                ),
              ),
              Text(
                'ShipTracker',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.tealAccent,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
