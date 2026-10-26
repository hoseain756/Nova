import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Compact player prompt with separate dismiss and action targets.
class PlayerBlurActionPill extends StatelessWidget {
  const PlayerBlurActionPill({
    super.key,
    required this.label,
    required this.onAction,
    required this.onDismiss,
    this.dismissTooltip,
  });

  final String label;
  final VoidCallback onAction;
  final VoidCallback onDismiss;
  final String? dismissTooltip;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48, maxWidth: 300),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Material(
              color:
                  Theme.of(context).colorScheme.surface.withValues(alpha: 0.72),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: onDismiss,
                    tooltip: dismissTooltip ??
                        MaterialLocalizations.of(context).closeButtonTooltip,
                    icon: const Icon(LucideIcons.x, size: 18),
                    color: Theme.of(context).colorScheme.onSurface,
                    constraints:
                        const BoxConstraints(minWidth: 48, minHeight: 48),
                  ),
                  Flexible(
                    child: TextButton(
                      onPressed: onAction,
                      style: TextButton.styleFrom(
                        foregroundColor:
                            Theme.of(context).colorScheme.onSurface,
                        minimumSize: const Size(0, 48),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                      ),
                      child: Text(
                        label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontWeight: FontWeight.w700,
                            ),
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
