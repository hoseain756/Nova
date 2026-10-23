import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/horse_theme.dart';
import '../../../l10n/nova_strings.dart';
import '../segments/skip_segment.dart';

String skipSegmentLabelKey(SkipSegmentType type) => switch (type) {
      SkipSegmentType.recap => 'playerSkipRecap',
      SkipSegmentType.intro => 'message24',
      SkipSegmentType.opening => 'playerSkipOpening',
      SkipSegmentType.outro => 'message25',
      SkipSegmentType.credits => 'playerSkipCredits',
    };

String skipSegmentDoneKey(SkipSegmentType type) => switch (type) {
      SkipSegmentType.recap => 'playerRecapSkipped',
      SkipSegmentType.intro => 'message12',
      SkipSegmentType.opening => 'playerOpeningSkipped',
      SkipSegmentType.outro => 'message13',
      SkipSegmentType.credits => 'playerCreditsSkipped',
    };

class PlayerSkipSegmentPill extends StatelessWidget {
  const PlayerSkipSegmentPill({
    super.key,
    required this.segment,
    required this.english,
    required this.onTap,
  });

  final SkipSegment segment;
  final bool english;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label =
        NovaStrings.lookup(english, skipSegmentLabelKey(segment.type));
    final icon =
        segment.isEnding ? LucideIcons.skipForward : LucideIcons.fastForward;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48, maxWidth: 300),
      child: Material(
        color: NovaColors.ink.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 18, color: NovaColors.white),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: NovaColors.white,
                          fontWeight: FontWeight.w700,
                        ),
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
