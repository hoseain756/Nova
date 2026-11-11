import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show Bidi;
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/models/media_item.dart';
import '../../core/theme/nova_theme.dart';
import 'image_decode.dart';
import 'nova_network_image.dart';

/// A panoramic still above the caption on phones, or beside it at 700 dp.
/// The caption sets its own height, including when accessibility text wraps.
class MediaHero extends StatelessWidget {
  const MediaHero({
    super.key,
    required this.item,
    required this.actions,
    this.artworkUrl,
    this.title,
    this.genre,
    this.story,
    this.detail = false,
    this.immersive = false,
    this.topChrome = false,
    this.selector,
    this.onArtworkTap,
    this.onSwipeStart,
    this.onSwipe,
  });

  final MediaItem item;
  final String? artworkUrl, title, genre, story;
  final Widget actions;
  final Widget? selector;
  final bool detail, immersive, topChrome;
  final VoidCallback? onArtworkTap;
  final GestureDragStartCallback? onSwipeStart;
  final GestureDragEndCallback? onSwipe;

  static String? artwork(MediaItem item,
          [String? landscape, String? portrait]) =>
      [landscape, item.background, item.poster, portrait]
          .whereType<String>()
          .where((url) => url.trim().isNotEmpty)
          .firstOrNull;

  @override
  Widget build(BuildContext context) {
    if (immersive) return _buildImmersive(context);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final canvas = theme.scaffoldBackgroundColor;
    final direction = Directionality.of(context);
    final align =
        direction == TextDirection.rtl ? TextAlign.right : TextAlign.left;
    TextDirection contentDirection(String text) {
      if (Bidi.startsWithRtl(text)) return TextDirection.rtl;
      if (Bidi.startsWithLtr(text)) return TextDirection.ltr;
      return direction;
    }

    return ColoredBox(
        color: canvas,
        child: LayoutBuilder(builder: (context, constraints) {
          final width = constraints.maxWidth;
          final wide = width >= 700;
          final gutter = wide ? 32.0 : 16.0;
          final artWidth = wide ? width * .56 : width;
          final url = artwork(item, artworkUrl);
          final overview = story ?? item.description;
          final category = genre ?? item.genres.firstOrNull;
          final facts = <Widget>[
            if (category?.isNotEmpty == true)
              Container(
                padding: const EdgeInsetsDirectional.only(start: 8),
                decoration: BoxDecoration(
                    border: BorderDirectional(
                        start: BorderSide(color: colors.primary, width: 3))),
                child: Text(category!),
              ),
            if (item.releaseInfo?.isNotEmpty == true) Text(item.releaseInfo!),
            if (item.runtime?.isNotEmpty == true)
              Text(item.runtime!,
                  textDirection: contentDirection(item.runtime!)),
            if (item.certification?.isNotEmpty == true)
              DecoratedBox(
                  decoration: BoxDecoration(
                      border: Border.all(color: colors.outline),
                      borderRadius: BorderRadius.circular(4)),
                  child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      child: Text(item.certification!,
                          textDirection: TextDirection.ltr))),
            if (detail && double.tryParse(item.rating ?? '') != null)
              Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(LucideIcons.star, size: 15, color: colors.secondary),
                const SizedBox(width: 4),
                Text(item.rating!)
              ]),
          ];
          final caption = Padding(
            padding: EdgeInsetsDirectional.fromSTEB(
                gutter,
                wide && topChrome
                    ? MediaQuery.paddingOf(context).top + 76
                    : wide
                        ? 28
                        : 10,
                wide ? 12 : gutter,
                22),
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (facts.isNotEmpty) ...[
                    DefaultTextStyle(
                        style: theme.textTheme.labelMedium!
                            .copyWith(color: colors.onSurfaceVariant),
                        child: Wrap(
                            spacing: 10,
                            runSpacing: 5,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: facts)),
                    const SizedBox(height: 8),
                  ],
                  Semantics(
                      header: true,
                      child: Text(title ?? item.name,
                          textAlign: align,
                          textDirection: contentDirection(title ?? item.name),
                          style: theme.textTheme.headlineLarge?.copyWith(
                              fontSize: wide ? 48 : 36,
                              height: 1.2,
                              fontWeight: FontWeight.w700))),
                  if ((wide || detail) &&
                      overview?.trim().isNotEmpty == true) ...[
                    const SizedBox(height: 12),
                    if (detail)
                      SelectableText(overview!,
                          textAlign: align,
                          textDirection: contentDirection(overview),
                          style: theme.textTheme.bodyLarge?.copyWith(
                              color: colors.onSurfaceVariant, height: 1.6))
                    else
                      Text(overview!,
                          textAlign: align,
                          textDirection: contentDirection(overview),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyLarge
                              ?.copyWith(color: colors.onSurfaceVariant)),
                  ],
                  const SizedBox(height: 16),
                  actions,
                ]),
          );
          final frame = Stack(
              key: const ValueKey('media-hero-frame'),
              fit: StackFit.expand,
              children: [
                GestureDetector(
                  excludeFromSemantics: true,
                  onTap: onArtworkTap,
                  onHorizontalDragStart: onSwipeStart,
                  onHorizontalDragEnd: onSwipe,
                  child: ColoredBox(
                      color: colors.surfaceContainerHighest,
                      child: url == null
                          ? Icon(LucideIcons.film,
                              size: 48, color: colors.onSurfaceVariant)
                          : NovaNetworkImage(url,
                              fit: BoxFit.cover,
                              cacheWidth: imageCacheWidth(context, artWidth),
                              excludeFromSemantics: true)),
                ),
                IgnorePointer(
                    child: DecoratedBox(
                        decoration: BoxDecoration(
                            gradient: LinearGradient(
                  begin: wide
                      ? AlignmentDirectional.centerStart
                      : Alignment.bottomCenter,
                  end: wide
                      ? AlignmentDirectional.centerEnd
                      : Alignment.topCenter,
                  colors: [canvas, canvas.withValues(alpha: 0)],
                  stops: const [0, .22],
                )))),
                if (topChrome && MediaQuery.paddingOf(context).top > 0)
                  PositionedDirectional(
                    top: 0,
                    start: 0,
                    end: 0,
                    height: MediaQuery.paddingOf(context).top + 12,
                    child: IgnorePointer(
                        child: DecoratedBox(
                            decoration: BoxDecoration(
                                gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                          canvas.withValues(alpha: .72),
                          canvas.withValues(alpha: 0)
                        ])))),
                  ),
                if (selector != null)
                  PositionedDirectional(
                      start: gutter, end: gutter, bottom: 4, child: selector!),
              ]);
          if (!wide) {
            return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                      height: (width * .55).clamp(160.0, 320.0), child: frame),
                  caption,
                ]);
          }
          return ConstrainedBox(
              constraints: BoxConstraints(
                  minWidth: width,
                  minHeight: (width * .33).clamp(230.0, 420.0)),
              child:
                  Stack(alignment: AlignmentDirectional.centerStart, children: [
                SizedBox(width: width - artWidth, child: caption),
                PositionedDirectional(
                    top: 0, bottom: 0, end: 0, width: artWidth, child: frame),
              ]));
        }));
  }

  Widget _buildImmersive(BuildContext context) {
    final theme = Theme.of(context);
    final direction = Directionality.of(context);
    final height = MediaQuery.sizeOf(context).height * .78;
    final url = artwork(item, artworkUrl);
    final displayTitle = title ?? item.name;
    final overview = story ?? item.description;
    final category = genre ?? item.genres.firstOrNull;
    final titleDirection = Bidi.startsWithRtl(displayTitle)
        ? TextDirection.rtl
        : Bidi.startsWithLtr(displayTitle)
            ? TextDirection.ltr
            : direction;
    final facts = <String>[
      if (category?.trim().isNotEmpty == true) category!,
      if (item.releaseInfo?.trim().isNotEmpty == true) item.releaseInfo!,
      if (item.runtime?.trim().isNotEmpty == true) item.runtime!,
    ];
    return SizedBox(
      height: height,
      child: LayoutBuilder(builder: (context, constraints) {
        final width = constraints.maxWidth;
        final wide = width >= 700;
        final gutter = NovaSpace.gutter(width);
        final captionBottom = wide
            ? 28.0
            : selector == null
                ? 28.0
                : 76.0;
        final topClearance =
            topChrome ? MediaQuery.paddingOf(context).top + 76 : 24.0;
        return Stack(fit: StackFit.expand, children: [
          Stack(
              key: const ValueKey('media-hero-frame'),
              fit: StackFit.expand,
              children: [
                GestureDetector(
                  excludeFromSemantics: true,
                  onTap: onArtworkTap,
                  onHorizontalDragStart: onSwipeStart,
                  onHorizontalDragEnd: onSwipe,
                  child: ColoredBox(
                    color: NovaColors.graphite,
                    child: url == null
                        ? const Center(
                            child: Icon(LucideIcons.film,
                                size: 56, color: NovaColors.mist))
                        : NovaNetworkImage(url,
                            fit: BoxFit.cover,
                            cacheWidth: imageCacheWidth(context, width),
                            excludeFromSemantics: true),
                  ),
                ),
                IgnorePointer(
                    child: DecoratedBox(
                  decoration: BoxDecoration(
                      gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0, .28, .55, 1],
                    colors: [
                      NovaColors.ink.withValues(alpha: topChrome ? .64 : .24),
                      NovaColors.ink.withValues(alpha: 0),
                      NovaColors.ink.withValues(alpha: .34),
                      NovaColors.ink.withValues(alpha: .98),
                    ],
                  )),
                )),
                if (wide)
                  IgnorePointer(
                      child: DecoratedBox(
                    decoration: BoxDecoration(
                        gradient: LinearGradient(
                      begin: AlignmentDirectional.centerStart,
                      end: AlignmentDirectional.centerEnd,
                      stops: const [0, .65, 1],
                      colors: [
                        NovaColors.ink.withValues(alpha: .62),
                        NovaColors.ink.withValues(alpha: .18),
                        NovaColors.ink.withValues(alpha: 0),
                      ],
                    )),
                  )),
              ]),
          PositionedDirectional(
            start: gutter,
            end: wide ? null : gutter,
            width: wide ? (width * .53).clamp(360.0, 650.0) : null,
            bottom: captionBottom,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                  maxHeight: (height - topClearance - captionBottom)
                      .clamp(80.0, height)),
              child: SingleChildScrollView(
                primary: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (facts.isNotEmpty) ...[
                      Wrap(spacing: 12, runSpacing: 4, children: [
                        for (final fact in facts)
                          Text(fact,
                              textDirection: Bidi.startsWithRtl(fact)
                                  ? TextDirection.rtl
                                  : TextDirection.ltr,
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: NovaColors.white.withValues(alpha: .84),
                                fontWeight: FontWeight.w600,
                              )),
                      ]),
                      const SizedBox(height: 10),
                    ],
                    Semantics(
                        header: true,
                        child: Text(
                          displayTitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textDirection: titleDirection,
                          style: theme.textTheme.headlineLarge?.copyWith(
                            color: NovaColors.white,
                            fontSize: wide ? 44 : 36,
                            height: 1.12,
                            fontWeight: FontWeight.w700,
                            shadows: const [
                              Shadow(
                                color: NovaColors.ink,
                                blurRadius: 20,
                              )
                            ],
                          ),
                        )),
                    if (wide && overview?.trim().isNotEmpty == true) ...[
                      const SizedBox(height: 12),
                      Text(
                        overview!,
                        textDirection: Bidi.startsWithRtl(overview)
                            ? TextDirection.rtl
                            : Bidi.startsWithLtr(overview)
                                ? TextDirection.ltr
                                : direction,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: NovaColors.white.withValues(alpha: .88),
                          height: 1.45,
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),
                    Theme(
                        data: theme.copyWith(
                          outlinedButtonTheme: OutlinedButtonThemeData(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: NovaColors.white,
                              backgroundColor:
                                  NovaColors.ink.withValues(alpha: .46),
                              side: BorderSide(
                                  color:
                                      NovaColors.white.withValues(alpha: .62)),
                              minimumSize: const Size(48, 48),
                            ),
                          ),
                        ),
                        child: actions),
                  ],
                ),
              ),
            ),
          ),
          if (selector != null)
            PositionedDirectional(
              start: gutter,
              end: gutter,
              bottom: 14,
              child: selector!,
            ),
        ]);
      }),
    );
  }
}
