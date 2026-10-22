import 'package:flutter/material.dart';
import 'package:nova_mobile/l10n/nova_strings.dart';

/// Drag the central delay value up/down for 10 ms steps. The stored value
/// remains an integer in milliseconds, including values from older settings.
class PreciseDelayValue extends StatefulWidget {
  const PreciseDelayValue({
    super.key,
    required this.valueMs,
    required this.english,
    required this.onDeltaMs,
    this.semanticLabel,
  });

  final int valueMs;
  final bool english;
  final ValueChanged<int> onDeltaMs;
  final String? semanticLabel;

  @override
  State<PreciseDelayValue> createState() => _PreciseDelayValueState();
}

class _PreciseDelayValueState extends State<PreciseDelayValue> {
  double _dragPixels = 0;

  void _drag(double deltaY) {
    _dragPixels -= deltaY;
    final steps = _dragPixels ~/ 12;
    if (steps == 0) return;
    _dragPixels -= steps * 12;
    widget.onDeltaMs(steps * 10);
  }

  @override
  Widget build(BuildContext context) => Semantics(
        label: widget.semanticLabel ??
            NovaStrings.lookup(widget.english, 'message74'),
        value: '${(widget.valueMs / 1000).toStringAsFixed(3)} s',
        increasedValue:
            '${((widget.valueMs + 10) / 1000).toStringAsFixed(3)} s',
        decreasedValue:
            '${((widget.valueMs - 10) / 1000).toStringAsFixed(3)} s',
        onIncrease: () => widget.onDeltaMs(10),
        onDecrease: () => widget.onDeltaMs(-10),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onVerticalDragStart: (_) => _dragPixels = 0,
          onVerticalDragUpdate: (details) => _drag(details.delta.dy),
          onVerticalDragEnd: (_) => _dragPixels = 0,
          onVerticalDragCancel: () => _dragPixels = 0,
          child: SizedBox(
            height: 48,
            child: Center(
              child: Text(
                '${(widget.valueMs / 1000).toStringAsFixed(3)} s',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w700,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
        ),
      );
}
