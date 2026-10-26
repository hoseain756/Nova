import 'package:flutter/material.dart';

import '../../../l10n/nova_strings.dart';
import '../segments/skip_segment.dart';
import 'player_blur_action_pill.dart';

String skipSegmentLabelKey(SkipSegmentType type) =>
    type == SkipSegmentType.outro || type == SkipSegmentType.credits
        ? 'message25'
        : 'message24';

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
    required this.onDismiss,
  });

  final SkipSegment segment;
  final bool english;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) => PlayerBlurActionPill(
        label: NovaStrings.lookup(english, skipSegmentLabelKey(segment.type)),
        onAction: onTap,
        onDismiss: onDismiss,
      );
}
