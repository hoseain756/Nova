import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nova_mobile/core/theme/nova_theme.dart';
import 'package:nova_mobile/features/splash/nova_splash.dart';
import 'package:nova_mobile/l10n/nova_strings.dart';

Widget _host({
  required Size size,
  required Brightness brightness,
  required bool reduceMotion,
  required TextDirection direction,
  required VoidCallback onFinished,
  Widget footer = const Text('Loading', textAlign: TextAlign.center),
  TextScaler textScaler = TextScaler.noScaling,
  Locale locale = const Locale('en'),
}) {
  final theme = NovaTheme.build(brightness);
  return MaterialApp(
    theme: theme,
    locale: locale,
    supportedLocales: const [Locale('ar'), Locale('en')],
    localizationsDelegates: const [
      NovaStrings.delegate,
      ...GlobalMaterialLocalizations.delegates,
    ],
    home: Center(
      child: SizedBox(
        width: size.width,
        height: size.height,
        child: MediaQuery(
          data: MediaQueryData(
            size: size,
            disableAnimations: reduceMotion,
            textScaler: textScaler,
          ),
          child: Directionality(
            textDirection: direction,
            child: NovaSplash(
              onFinished: onFinished,
              footer: footer,
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('plays once, completes once, and does not replay on rebuild',
      (tester) async {
    var completions = 0;
    Widget app(
      Brightness brightness, {
      TextDirection direction = TextDirection.ltr,
      Locale locale = const Locale('en'),
    }) =>
        _host(
          size: const Size(390, 780),
          brightness: brightness,
          reduceMotion: false,
          direction: direction,
          locale: locale,
          onFinished: () => completions++,
        );

    await tester.pumpWidget(app(Brightness.dark));
    await tester.pump();
    expect(
      tester
          .widget<Opacity>(find.byKey(const ValueKey('nova-splash-symbol')))
          .opacity,
      0,
    );

    await tester.pump(const Duration(milliseconds: 700));
    expect(
      tester
          .widget<Opacity>(find.byKey(const ValueKey('nova-splash-symbol')))
          .opacity,
      closeTo(1, .001),
    );
    expect(completions, 0);

    await tester.pump(const Duration(milliseconds: 2710));
    await tester.pump();
    expect(completions, 1);

    await tester.pumpWidget(
      app(
        Brightness.light,
        direction: TextDirection.rtl,
        locale: const Locale('ar'),
      ),
    );
    await tester.pump(const Duration(seconds: 5));
    expect(completions, 1);
    expect(
      tester
          .widget<ColoredBox>(
            find.byKey(const ValueKey('nova-splash-background')),
          )
          .color,
      NovaColors.lightBackground,
    );
  });

  testWidgets('reduced motion snaps to the final lockup without a ticker',
      (tester) async {
    var completions = 0;
    await tester.pumpWidget(
      _host(
        size: const Size(390, 780),
        brightness: Brightness.dark,
        reduceMotion: true,
        direction: TextDirection.ltr,
        onFinished: () => completions++,
      ),
    );
    await tester.pump();

    expect(completions, 1);
    expect(
      tester
          .widget<Opacity>(find.byKey(const ValueKey('nova-splash-symbol')))
          .opacity,
      1,
    );
    expect(
      tester
          .widget<ColoredBox>(
            find.byKey(const ValueKey('nova-splash-background')),
          )
          .color,
      NovaColors.ink,
    );

    await tester.pump(const Duration(seconds: 5));
    expect(completions, 1);
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('fits compact landscape and keeps brand geometry fixed in RTL',
      (tester) async {
    Future<Rect> pumpAt(Size size, TextDirection direction) async {
      await tester.pumpWidget(
        _host(
          size: size,
          brightness: Brightness.light,
          reduceMotion: true,
          direction: direction,
          onFinished: () {},
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      final splashRect = tester.getRect(
        find.byKey(const ValueKey('nova-splash-background')),
      );
      final logoRect =
          tester.getRect(find.byKey(const ValueKey('nova-splash-lockup')));
      expect(splashRect.contains(logoRect.topLeft), isTrue);
      expect(splashRect.contains(logoRect.bottomRight), isTrue);
      return tester.getRect(
        find.byKey(const ValueKey('nova-splash-symbol')),
      );
    }

    final landscapeLtr = await pumpAt(const Size(800, 400), TextDirection.ltr);
    final landscapeRtl = await pumpAt(const Size(800, 400), TextDirection.rtl);
    expect(landscapeRtl, landscapeLtr);

    await pumpAt(const Size(320, 480), TextDirection.rtl);
    expect(tester.takeException(), isNull);
  });

  testWidgets('scrolls a 200 percent error footer on short landscape',
      (tester) async {
    await tester.pumpWidget(
      _host(
        size: const Size(800, 300),
        brightness: Brightness.dark,
        reduceMotion: true,
        direction: TextDirection.rtl,
        textScaler: const TextScaler.linear(2),
        onFinished: () {},
        footer: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'تعذر تشغيل NOVA',
              style: NovaTheme.dark.textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            const Text(
              'حدث خطأ أثناء بدء التشغيل. تحقق من الاتصال ثم أعد المحاولة.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton(onPressed: null, child: Text('إعادة المحاولة')),
          ],
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byType(SingleChildScrollView), findsOneWidget);
    await tester.drag(
        find.byType(SingleChildScrollView), const Offset(0, -160));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
