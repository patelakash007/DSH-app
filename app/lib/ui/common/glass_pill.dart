// Portions derived from PiPilot (https://github.com/CikeSeven/pi_pilot), MIT, Copyright (c) 2026 CikeSeven. See THIRD_PARTY_NOTICES.md.

import 'package:flutter/material.dart';

import '../theme/glass.dart';
import '../theme/motion.dart';
import '../theme/shapes.dart';
import '../theme/squircle.dart';
import '../theme/surfaces.dart';
import 'smooth_size.dart';

///

class GlassPill extends StatelessWidget {
  const GlassPill({super.key, required this.child, this.onTap, this.expandedChild, this.fillWidth = true});

  final Widget child;
  final VoidCallback? onTap;

  final bool fillWidth;

  final Widget? expandedChild;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final expanded = expandedChild != null;

    final body = Material(
      type: MaterialType.transparency,
      child: Column(
        crossAxisAlignment: fillWidth ? CrossAxisAlignment.stretch : CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [

          InkWell(
            onTap: onTap,
            customBorder: expanded
                ? const RoundedSuperellipseBorder(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(AppShape.md)),
                  )
                : const StadiumBorder(),
            child: Container(
              constraints: const BoxConstraints(minHeight: 34),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),

              alignment: fillWidth ? Alignment.centerLeft : null,
              child: child,
            ),
          ),
          if (expandedChild case final content?) ...[
            Divider(height: 0.5, thickness: 0.5, color: colors.outlineVariant.withValues(alpha: 0.6)),
            SmoothSize(
              duration: AppMotion.of(context, AppMotion.collapse),
              curve: AppMotion.collapseCurve,
              alignment: Alignment.topCenter,
              child: content,
            ),
          ],
        ],
      ),
    );

    return GlassSurface(
      tier: GlassTier.pill,
      borderRadius: expanded ? AppShape.radiusMd : null,

      child: expanded ? Squircle.clip(radius: AppShape.md, child: body) : body,
    );
  }
}
