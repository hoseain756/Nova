import 'package:flutter/widgets.dart';

/// Retains the actual surface widget across unrelated parent/progress builds.
/// An identity or explicit geometry change is the only rebuild boundary.
class PlaybackSessionSurface extends StatefulWidget {
  const PlaybackSessionSurface(
      {super.key,
      required this.identity,
      required this.geometry,
      required this.buildSurface});
  final Object identity;
  final Object geometry;
  final Widget Function() buildSurface;
  @override
  State<PlaybackSessionSurface> createState() => _PlaybackSessionSurfaceState();
}

class _PlaybackSessionSurfaceState extends State<PlaybackSessionSurface> {
  late Widget _surface = widget.buildSurface();
  @override
  void didUpdateWidget(covariant PlaybackSessionSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.identity, widget.identity) ||
        oldWidget.geometry != widget.geometry) {
      _surface = widget.buildSurface();
    }
  }

  @override
  Widget build(BuildContext context) => _surface;
}
