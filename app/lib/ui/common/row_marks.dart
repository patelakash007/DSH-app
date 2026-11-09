// The trailing marks of a list or settings row besides
// the chevron (`OverviewChevron`): the ✓ of a picked row and the ⌄ of a row
// that unfolds in place. Each is placed by its ink, not its glyph box, so it
// ends on the row's 16dp right edge — where a chevron's ink, a switch track, a
// value or a status dot ends.

import 'package:flutter/material.dart';

import '../theme/app_icons.dart';
import '../theme/theme.dart';

///

class RowCheck extends StatelessWidget {
  const RowCheck({super.key, this.visible = true});

  final bool visible;

  static const size = 20.0;

  /// Blank right of the glyph's ink (`check_rounded`: path max x 20.58 of 24).
  static const nudge = (24 - 20.58) / 24 * size;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: visible
        ? Transform.translate(
            offset: const Offset(nudge, 0),
            child: Icon(AppIcons.selected, size: size, color: Theme.of(context).colorScheme.primary),
          )
        : null,
  );
}

///

class RowExpandArrow extends StatelessWidget {
  const RowExpandArrow({super.key, required this.open});

  final bool open;

  static const size = 20.0;

  /// Width of the glyph's ink (`expand_more_rounded`: x 6.42–17.58 of 24).
  /// The glyph is mirror-symmetric, so turning it keeps the ink in place.
  static const inkWidth = (17.58 - 6.42) / 24 * size;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: inkWidth,
    height: size,
    child: OverflowBox(
      minWidth: size,
      maxWidth: size,
      child: AnimatedRotation(
        turns: open ? 0.5 : 0,
        duration: AppMotion.of(context, AppMotion.standard),
        curve: AppMotion.std,
        child: Icon(AppIcons.expand, size: size, color: DshColors.of(context).textTertiary),
      ),
    ),
  );
}
