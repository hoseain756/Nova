import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nova_mobile/features/player/widgets/player_session_surface.dart';

void main() {
  for (final direction in TextDirection.values) {
    for (final brightness in Brightness.values) {
      for (final size in [const Size(844, 390), const Size(1180, 820)]) {
        testWidgets(
            'stable surface across progress/panels $direction $brightness $size',
            (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          var builds = 0;
          final identity = Object();
          Widget host(int tick, {BoxFit fit = BoxFit.contain}) => MaterialApp(
                theme: ThemeData(brightness: brightness),
                home: Directionality(
                    textDirection: direction,
                    child: Scaffold(
                        body: Stack(fit: StackFit.expand, children: [
                      PlaybackSessionSurface(
                          identity: identity,
                          geometry: fit,
                          buildSurface: () => _Probe(onBuild: () => builds++)),
                      Text('$tick'),
                      if (tick.isOdd)
                        const Align(
                            alignment: AlignmentDirectional.centerEnd,
                            child: SizedBox(width: 200, child: Text('Panel'))),
                    ]))),
              );
          await tester.pumpWidget(host(0));
          expect(builds, 1);
          for (var tick = 1; tick <= 20; tick++) {
            await tester.pumpWidget(host(tick));
          }
          expect(builds, 1);
          await tester.pumpWidget(host(21, fit: BoxFit.cover));
          expect(builds, 2);
          expect(tester.takeException(), isNull);
        });
      }
    }
  }
}

class _Probe extends StatelessWidget {
  const _Probe({required this.onBuild});
  final VoidCallback onBuild;
  @override
  Widget build(BuildContext context) {
    onBuild();
    return const ColoredBox(color: Colors.black);
  }
}
