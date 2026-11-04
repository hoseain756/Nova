import 'package:flutter/material.dart';

import '../../l10n/nova_strings.dart';
import 'dock_tab.dart';
import 'glass_dock.dart';

/// Android's Material 3 navigation surface uses the same route intents as the
/// native iOS bar. Its shape floats; its content padding is reserved by pages.
class MaterialFloatingDock extends StatelessWidget {
  const MaterialFloatingDock(
      {super.key,
      required this.tabs,
      required this.activeId,
      required this.onTabSelected,
      required this.arabic,
      this.hidden = false,
      this.previewMode = false,
      this.style = NavigationBarStyle.classic});
  final List<DockTab> tabs;
  final String activeId;
  final ValueChanged<DockTab> onTabSelected;
  final bool arabic, hidden, previewMode;
  final NavigationBarStyle style;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final selected = tabs.indexWhere((tab) => tab.id == activeId);
    final mini = style == NavigationBarStyle.mini;
    final iconsOnly = style != NavigationBarStyle.classic;
    final largeText = media.textScaler.scale(14) > 21;
    return ExcludeSemantics(
      excluding: hidden || previewMode,
      child: IgnorePointer(
        ignoring: hidden || previewMode,
        child: AnimatedOpacity(
          opacity: hidden ? 0 : 1,
          duration: media.disableAnimations
              ? Duration.zero
              : const Duration(milliseconds: 180),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsetsDirectional.fromSTEB(
                  mini ? 24 : 16, 0, mini ? 24 : 16, 12),
              child: Align(
                alignment: Alignment.bottomCenter,
                heightFactor: 1,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: mini ? 340 : 440),
                  child: Semantics(
                    container: true,
                    label: NovaStrings.lookup(!arabic, 'primaryNavigation'),
                    child: Material(
                      elevation: 3,
                      shadowColor: Theme.of(context)
                          .colorScheme
                          .shadow
                          .withValues(alpha: .2),
                      borderRadius: BorderRadius.circular(mini ? 26 : 32),
                      clipBehavior: Clip.antiAlias,
                      child: NavigationBar(
                        key: const ValueKey('nova-material-dock'),
                        height: mini ? 64 : 80,
                        backgroundColor:
                            Theme.of(context).colorScheme.surfaceContainer,
                        indicatorColor:
                            Theme.of(context).colorScheme.secondaryContainer,
                        animationDuration: media.disableAnimations
                            ? Duration.zero
                            : const Duration(milliseconds: 220),
                        selectedIndex: selected < 0 ? 0 : selected,
                        labelBehavior: iconsOnly || largeText
                            ? NavigationDestinationLabelBehavior.alwaysHide
                            : NavigationDestinationLabelBehavior
                                .onlyShowSelected,
                        onDestinationSelected: (index) =>
                            onTabSelected(tabs[index]),
                        destinations: [
                          for (final tab in tabs)
                            NavigationDestination(
                              icon: Icon(tab.iconOutline, size: 23),
                              selectedIcon: Icon(tab.iconFilled, size: 23),
                              label: tab.label(arabic: arabic),
                              tooltip: tab.label(arabic: arabic),
                            )
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
