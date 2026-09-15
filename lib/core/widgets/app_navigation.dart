import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:hrm_app/core/theme/app_theme.dart';

class AppNavigationItem {
  const AppNavigationItem({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

class AppQuickActionItem {
  const AppQuickActionItem({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
}

class AppFloatingNavigation extends StatelessWidget {
  const AppFloatingNavigation({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.onCenterPressed,
    this.centerLabel = 'Buka absensi',
    this.onQuickActionsPressed,
    this.quickActionsExpanded = false,
  }) : assert(items.length == 4);

  final List<AppNavigationItem> items;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final VoidCallback onCenterPressed;
  final String centerLabel;
  final VoidCallback? onQuickActionsPressed;
  final bool quickActionsExpanded;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textScale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 2.0);
    final navHeight = 76 + ((textScale - 1) * 20);

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      child: SizedBox(
        height: navHeight + 25,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.bottomCenter,
          children: [
            Container(
              key: const ValueKey('floating-navigation-surface'),
              height: navHeight,
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(AppRadius.navigation),
                boxShadow: AppShadows.navigation,
              ),
              child: Row(
                children: [
                  _NavigationButton(
                    item: items[0],
                    selected: selectedIndex == 0,
                    onPressed: () => onDestinationSelected(0),
                  ),
                  _NavigationButton(
                    item: items[1],
                    selected: selectedIndex == 1,
                    onPressed: () => onDestinationSelected(1),
                  ),
                  const SizedBox(width: 70),
                  _NavigationButton(
                    item: items[2],
                    selected: selectedIndex == 2,
                    onPressed: () => onDestinationSelected(2),
                  ),
                  _NavigationButton(
                    item: items[3],
                    selected: selectedIndex == 3,
                    onPressed: () => onDestinationSelected(3),
                  ),
                ],
              ),
            ),
            Positioned(
              top: 0,
              child: Semantics(
                button: true,
                label: centerLabel,
                child: Tooltip(
                  message: centerLabel,
                  child: Material(
                    color: colors.primary,
                    elevation: 0,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: InkWell(
                      key: const ValueKey('attendance-center-action'),
                      borderRadius: BorderRadius.circular(24),
                      onTap: onCenterPressed,
                      child: SizedBox.square(
                        dimension: 62,
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Theme.of(context).scaffoldBackgroundColor,
                              width: 5,
                            ),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Icon(
                            Icons.center_focus_strong_rounded,
                            color: colors.onPrimary,
                            size: 25,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavigationButton extends StatelessWidget {
  const _NavigationButton({
    required this.item,
    required this.selected,
    required this.onPressed,
  });

  final AppNavigationItem item;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Expanded(
      child: Semantics(
        selected: selected,
        button: true,
        label: item.label,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(AppRadius.icon),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 7),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    selected ? item.selectedIcon : item.icon,
                    size: 21,
                    color: selected
                        ? colors.primary
                        : textTheme.bodySmall?.color,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    item.label,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    style: textTheme.labelSmall?.copyWith(
                      color: selected
                          ? colors.primary
                          : textTheme.bodySmall?.color,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AppQuickActionOverlay extends StatelessWidget {
  const AppQuickActionOverlay({
    super.key,
    required this.actions,
    required this.onDismiss,
  });

  final List<AppQuickActionItem> actions;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    if (actions.isEmpty) return const SizedBox.shrink();
    return Positioned.fill(
      child: CallbackShortcuts(
        bindings: {const SingleActivator(LogicalKeyboardKey.escape): onDismiss},
        child: Focus(
          autofocus: true,
          child: Stack(
            children: [
              Positioned.fill(
                child: Semantics(
                  button: true,
                  label: 'Tutup menu aksi cepat',
                  child: GestureDetector(
                    key: const ValueKey('quick-action-backdrop'),
                    behavior: HitTestBehavior.opaque,
                    onTap: onDismiss,
                    child: const ColoredBox(color: Colors.transparent),
                  ),
                ),
              ),
              Positioned(
                right: 22,
                bottom: 166 + MediaQuery.paddingOf(context).bottom,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: actions
                      .map(
                        (action) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _QuickActionButton(
                            item: action,
                            onDismiss: onDismiss,
                          ),
                        ),
                      )
                      .toList(growable: false),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  const _QuickActionButton({required this.item, required this.onDismiss});

  final AppQuickActionItem item;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surface,
    elevation: 4,
    shadowColor: Colors.black.withValues(alpha: 0.22),
    borderRadius: BorderRadius.circular(16),
    child: InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        onDismiss();
        item.onPressed();
      },
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              item.label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 9),
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(item.icon, size: 15),
            ),
          ],
        ),
      ),
    ),
  );
}

class AppQuickActionFab extends StatelessWidget {
  const AppQuickActionFab({
    super.key,
    required this.expanded,
    required this.onPressed,
  });

  final bool expanded;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: expanded ? 'Tutup aksi cepat' : 'Buka aksi cepat',
    child: Material(
      color: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFFE8EDF6)
          : AppColors.lightText,
      elevation: 7,
      shadowColor: Colors.black.withValues(alpha: 0.38),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(18),
        child: SizedBox.square(
          dimension: 50,
          child: AnimatedRotation(
            turns: expanded ? 0.125 : 0,
            duration: AppMotion.durationOf(context, AppMotion.control),
            child: Icon(
              Icons.add_rounded,
              color: Theme.of(context).brightness == Brightness.dark
                  ? AppColors.darkBg
                  : Colors.white,
              size: 22,
            ),
          ),
        ),
      ),
    ),
  );
}
