import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../core/models/visual_preferences.dart';
import 'image_decode.dart';
import 'shimmer_box.dart';

/// Disk-backed images, bounded decode size, geometry-stable placeholder and fade.
class NovaNetworkImage extends StatelessWidget {
  const NovaNetworkImage(this.url,
      {super.key,
      this.width,
      this.height,
      this.fit,
      this.cacheWidth,
      this.cacheHeight,
      this.errorBuilder,
      this.loadingBuilder,
      this.frameBuilder,
      this.alignment = Alignment.center,
      this.color,
      this.colorBlendMode,
      this.headers,
      this.semanticLabel,
      this.excludeFromSemantics = false,
      this.gaplessPlayback = false,
      this.filterQuality = FilterQuality.low,
      this.quality,
      this.providerKind = ProviderImageKind.poster});
  final String url;
  final double? width, height;
  final BoxFit? fit;
  final int? cacheWidth, cacheHeight;
  final ImageErrorWidgetBuilder? errorBuilder;
  final ImageLoadingBuilder? loadingBuilder;
  final ImageFrameBuilder? frameBuilder;
  final AlignmentGeometry alignment;
  final Color? color;
  final BlendMode? colorBlendMode;
  final Map<String, String>? headers;
  final String? semanticLabel;
  final bool excludeFromSemantics, gaplessPlayback;
  final FilterQuality filterQuality;

  /// When provided, resize only recognized provider URLs for this role.
  final ImageQuality? quality;
  final ProviderImageKind providerKind;
  @override
  Widget build(BuildContext context) {
    final logicalWidth =
        width != null && width!.isFinite && width! > 0 ? width! : null;
    final targetPixels = cacheWidth ??
        (logicalWidth == null ? 2048 : imageCacheWidth(context, logicalWidth));
    final resolvedUrl = quality == null
        ? url
        : providerSizedImageUrl(url,
            quality: quality!, targetPixels: targetPixels, kind: providerKind);
    final decodeWidth = quality == null
        ? cacheWidth
        : cacheWidth == null
            ? logicalWidth == null
                ? null
                : imageCacheWidthForQuality(context, logicalWidth,
                    quality: quality!, kind: providerKind)
            : cacheWidth!.clamp(
                1,
                switch ((providerKind, quality!)) {
                  (ProviderImageKind.poster, ImageQuality.low) => 185,
                  (ProviderImageKind.poster, ImageQuality.medium) => 500,
                  (ProviderImageKind.poster, ImageQuality.high) => 780,
                  (ProviderImageKind.backdrop, ImageQuality.low) => 300,
                  (ProviderImageKind.backdrop, ImageQuality.medium) => 780,
                  (ProviderImageKind.backdrop, ImageQuality.high) => 1280,
                  _ => 2048,
                });
    return Image(
      image: ResizeImage.resizeIfNeeded(
          decodeWidth?.clamp(1, 2048),
          cacheHeight?.clamp(1, 2048),
          CachedNetworkImageProvider(resolvedUrl, headers: headers)),
      width: width,
      height: height,
      fit: fit,
      alignment: alignment,
      color: color,
      colorBlendMode: colorBlendMode,
      semanticLabel: semanticLabel,
      excludeFromSemantics: excludeFromSemantics,
      gaplessPlayback: gaplessPlayback,
      filterQuality: filterQuality,
      errorBuilder: errorBuilder ??
          (context, _, __) => ColoredBox(
              color: Theme.of(context).colorScheme.surfaceContainerHigh,
              child: Center(
                  child: Icon(LucideIcons.image,
                      color: Theme.of(context).colorScheme.onSurfaceVariant))),
      loadingBuilder: loadingBuilder,
      frameBuilder: frameBuilder ??
          (context, child, frame, synchronous) {
            if (synchronous || MediaQuery.disableAnimationsOf(context)) {
              return frame == null ? const ShimmerBox() : child;
            }
            return AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: frame == null
                    ? const ShimmerBox(key: ValueKey('loading'))
                    : child);
          },
    );
  }
}
