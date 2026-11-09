// How a dsh-ui answer (`[dsh-ui reply] …`) reads in the conversation: a small
// right-aligned tag instead of the raw reply text.

import 'package:flutter/material.dart';

import '../../theme/app_icons.dart';
import '../../theme/theme.dart';

///
/// ```

/// ```
///

class DshUiReplyChip extends StatelessWidget {
  const DshUiReplyChip({super.key, required this.label, this.pending = false});

  final String label;
  final bool pending;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Align(
      alignment: Alignment.centerRight,
      child: AnimatedOpacity(
        opacity: pending ? 0.6 : 1,
        duration: AppMotion.of(context, AppMotion.quick),
        child: DecoratedBox(
          decoration: ShapeDecoration(color: colors.primary.withValues(alpha: 0.1), shape: const StadiumBorder()),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 6, 14, 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(AppIcons.selected, size: 16, color: colors.primary),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelLarge?.copyWith(color: colors.primary, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
