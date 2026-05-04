import 'package:flutter/material.dart';

import '../../../core/constants/brand_constants.dart';
import '../../../core/theme/admin_colors.dart';

/// School crest for login hero and sidebar chrome.
class SchoolBrandLogo extends StatelessWidget {
  const SchoolBrandLogo({
    super.key,
    required this.height,
    this.borderRadius = 12,
  });

  final double height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Image.asset(
        BrandConstants.logoAsset,
        height: height,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            height: height,
            width: height,
            alignment: Alignment.center,
            color: AdminColors.borderSubtle,
            child: Icon(
              Icons.school_rounded,
              size: height * 0.5,
              color: AdminColors.primaryAction,
            ),
          );
        },
      ),
    );
  }
}
