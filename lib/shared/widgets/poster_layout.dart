import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/poster_card_style.dart';
import '../../core/state/app_state.dart';

PosterCardStyle watchPosterStyle(BuildContext context) =>
    context.select<AppState, PosterCardStyle>(
        (app) => PosterCardStyle.fromSettings(app.webSettings));

/// Measures the actual localized font at the current accessibility scale.
double posterLabelHeight(BuildContext context, double width,
    {bool release = true}) {
  double measure(TextStyle? style, int lines) {
    final painter = TextPainter(
      text:
          TextSpan(text: List.filled(lines, 'Ag أج').join('\n'), style: style),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      locale: Localizations.maybeLocaleOf(context),
      maxLines: lines,
    )..layout(maxWidth: width);
    final height = painter.height.ceilToDouble();
    painter.dispose();
    return height;
  }

  final text = Theme.of(context).textTheme;
  return 8 +
      measure(
          text.bodyMedium?.copyWith(fontWeight: FontWeight.w600, height: 1.3),
          2) +
      (release ? 3 + measure(text.bodySmall, 1) : 0);
}

/// Shared by every poster grid; a large or wide card may use one column.
class PosterGridMetrics {
  PosterGridMetrics(BuildContext context, double availableWidth,
      {required PosterCardStyle style,
      double preferredWidth = 190,
      this.spacing = 20,
      int maxColumns = 7}) {
    final available = math.max(1.0, availableWidth);
    final minColumns =
        style.landscape || style.scale > 1 || available < 240 ? 1 : 2;
    columns = (available / style.gridTargetWidth(preferredWidth))
        .floor()
        .clamp(minColumns, maxColumns);
    width = math.max(1.0, (available - (columns - 1) * spacing) / columns);
    extent = width / style.aspectRatio +
        (style.hideTitles ? 0 : posterLabelHeight(context, width));
  }

  late final int columns;
  late final double width;
  late final double extent;
  final double spacing;

  SliverGridDelegate get delegate => SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: columns,
      mainAxisExtent: extent,
      crossAxisSpacing: spacing,
      mainAxisSpacing: 24);
}
