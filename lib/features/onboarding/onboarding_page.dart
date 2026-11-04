import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../../core/state/app_state.dart';
import '../../core/theme/nova_theme.dart';
import '../../l10n/nova_strings.dart';
import '../../shared/widgets/nova_brand.dart';

class OnboardingPage extends StatelessWidget {
  const OnboardingPage({super.key, required this.onComplete});
  final VoidCallback onComplete;
  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final s = NovaStrings.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
        body: SafeArea(child: LayoutBuilder(builder: (context, constraints) {
      final wide = constraints.maxWidth >= 900;
      final intro =
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const NovaBrand(width: 160),
        const SizedBox(height: 48),
        Semantics(
            header: true,
            child: Text(s.text('welcomeTitle'),
                style: Theme.of(context).textTheme.displayMedium)),
        const SizedBox(height: 24),
        Text(s.text('welcomeBody'),
            style: Theme.of(context)
                .textTheme
                .bodyLarge
                ?.copyWith(color: scheme.onSurfaceVariant)),
        const SizedBox(height: 32),
        Divider(height: 1, color: scheme.outlineVariant),
      ]);
      final choices =
          Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Semantics(
            header: true,
            child: Text(s.text('language'),
                style: Theme.of(context).textTheme.titleLarge)),
        const SizedBox(height: 16),
        for (final language in [
          (false, s.text('arabicLanguage')),
          (true, s.text('englishLanguage')),
        ])
          _OnboardingChoice(
            title: language.$2,
            icon: LucideIcons.languages,
            selected: app.english == language.$1,
            onTap: () => app.setLanguage(language.$1),
          ),
        const SizedBox(height: 32),
        Semantics(
            header: true,
            child: Text(s.text('appearance'),
                style: Theme.of(context).textTheme.titleLarge)),
        const SizedBox(height: 16),
        for (final mode in [
          ('dark', LucideIcons.moon),
          ('light', LucideIcons.sun),
          ('system', LucideIcons.monitor),
        ])
          _OnboardingChoice(
            title: s.text(mode.$1),
            icon: mode.$2,
            selected: (app.webSettings['themeMode'] ?? 'dark') == mode.$1,
            onTap: () => app.setSetting('themeMode', mode.$1),
          ),
        const SizedBox(height: 32),
        FilledButton.icon(
            onPressed: onComplete,
            icon: const Icon(LucideIcons.play),
            label: Text(s.text('startExploring'))),
        const SizedBox(height: 16),
        Text(s.text('welcomePrivacy'),
            style: Theme.of(context).textTheme.bodySmall),
      ]);
      return Center(
          child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: SingleChildScrollView(
                padding:
                    EdgeInsets.all(NovaSpace.gutter(constraints.maxWidth) + 8),
                child: wide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                            Expanded(child: intro),
                            const SizedBox(width: 64),
                            Expanded(child: choices)
                          ])
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [intro, const SizedBox(height: 48), choices]),
              )));
    })));
  }
}

class _OnboardingChoice extends StatelessWidget {
  const _OnboardingChoice(
      {required this.title,
      required this.icon,
      required this.selected,
      required this.onTap});
  final String title;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 72),
            padding: const EdgeInsetsDirectional.symmetric(vertical: 16),
            decoration: BoxDecoration(
                border: Border(
                    bottom:
                        BorderSide(color: theme.colorScheme.outlineVariant))),
            child: Row(children: [
              Icon(icon,
                  color: selected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 16),
              Expanded(child: Text(title, style: theme.textTheme.titleMedium)),
              const SizedBox(width: 16),
              Icon(selected ? LucideIcons.circleCheck : LucideIcons.circle,
                  color: selected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant),
            ]),
          ),
        ),
      ),
    );
  }
}
