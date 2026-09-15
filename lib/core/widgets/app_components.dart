import 'package:flutter/material.dart';

import 'package:hrm_app/core/theme/app_theme.dart';

enum AppStatusTone { neutral, info, success, warning, danger }

class AppSurfaceCard extends StatelessWidget {
  const AppSurfaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.onTap,
    this.semanticLabel,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final card = Material(
      color: colors.surface,
      elevation: 1,
      shadowColor: AppColors.lightText.withValues(alpha: 0.12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );

    if (semanticLabel == null) return card;
    return Semantics(
      container: true,
      button: onTap != null,
      label: semanticLabel,
      child: card,
    );
  }
}

class AppSectionHeader extends StatelessWidget {
  const AppSectionHeader({
    super.key,
    required this.title,
    this.description,
    this.actionLabel,
    this.onAction,
  }) : assert((actionLabel == null) == (onAction == null));

  final String title;
  final String? description;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            if (description != null) ...[
              const SizedBox(height: AppSpacing.xxs),
              Text(description!, style: Theme.of(context).textTheme.bodySmall),
            ],
          ],
        ),
      ),
      if (actionLabel != null) ...[
        const SizedBox(width: AppSpacing.sm),
        TextButton(onPressed: onAction, child: Text(actionLabel!)),
      ],
    ],
  );
}

class AppStatusChip extends StatelessWidget {
  const AppStatusChip({
    super.key,
    required this.label,
    required this.tone,
    this.icon,
  });

  final String label;
  final AppStatusTone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final (foreground, background) = switch (tone) {
      AppStatusTone.neutral => (
        Theme.of(context).colorScheme.onSurface,
        Theme.of(context).colorScheme.surfaceContainer,
      ),
      AppStatusTone.info => (
        isDark ? AppColors.primaryLight : AppColors.primaryDark,
        isDark ? AppColors.darkTint : AppColors.primaryTint,
      ),
      AppStatusTone.success => (
        isDark ? AppColors.darkSuccess : AppColors.success,
        isDark ? AppColors.darkSuccessBackground : AppColors.successBackground,
      ),
      AppStatusTone.warning => (
        isDark ? AppColors.darkWarning : AppColors.warning,
        isDark ? AppColors.darkWarningBackground : AppColors.warningBackground,
      ),
      AppStatusTone.danger => (
        isDark ? AppColors.darkDanger : AppColors.danger,
        isDark ? AppColors.darkDangerBackground : AppColors.dangerBackground,
      ),
    };

    return Semantics(
      label: 'Status: $label',
      child: Container(
        constraints: const BoxConstraints(minHeight: 32),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 15, color: foreground),
              const SizedBox(width: AppSpacing.xs),
            ],
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: foreground,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AppLoadingIndicator extends StatelessWidget {
  const AppLoadingIndicator({
    super.key,
    this.linear = false,
    this.strokeWidth = 2.5,
    this.color,
    this.backgroundColor,
    this.semanticLabel = 'Memuat',
  });

  final bool linear;
  final double strokeWidth;
  final Color? color;
  final Color? backgroundColor;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    label: semanticLabel,
    child: ExcludeSemantics(
      child: AppMotion.disabledOf(context)
          ? Icon(
              Icons.hourglass_top_rounded,
              size: 20,
              color: color ?? Theme.of(context).colorScheme.primary,
            )
          : linear
          ? LinearProgressIndicator(
              minHeight: 3,
              color: color,
              backgroundColor: backgroundColor,
              borderRadius: const BorderRadius.all(Radius.circular(2)),
            )
          : CircularProgressIndicator(strokeWidth: strokeWidth, color: color),
    ),
  );
}

class AppInitialAvatar extends StatelessWidget {
  const AppInitialAvatar({
    super.key,
    required this.name,
    this.size = 44,
    this.semanticLabel,
  });

  final String name;
  final double size;
  final String? semanticLabel;

  String get _initials {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty);
    return parts
        .take(2)
        .map((part) => part.characters.first)
        .join()
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    image: true,
    label: semanticLabel ?? 'Avatar $name',
    child: ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.primary,
          shape: BoxShape.circle,
        ),
        child: Text(
          _initials.isEmpty ? '?' : _initials,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    ),
  );
}

class AppBadgeIconButton extends StatelessWidget {
  const AppBadgeIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.badgeCount,
    this.boxed = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final int? badgeCount;
  final bool boxed;

  @override
  Widget build(BuildContext context) {
    final count = badgeCount ?? 0;
    final badgeLabel = count > 99 ? '99+' : '$count';
    return Semantics(
      button: true,
      label: count > 0 ? '$tooltip, $count belum dibaca' : tooltip,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          IconButton(
            onPressed: onPressed,
            tooltip: tooltip,
            style: boxed
                ? IconButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.surface,
                    foregroundColor: Theme.of(context).colorScheme.onSurface,
                    minimumSize: const Size(44, 44),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(13),
                    ),
                  )
                : null,
            icon: Icon(icon, size: boxed ? 20 : null),
          ),
          if (count > 0)
            Positioned(
              top: 2,
              right: 1,
              child: ExcludeSemantics(
                child: Container(
                  constraints: const BoxConstraints(
                    minWidth: 18,
                    minHeight: 18,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.error,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.surface,
                      width: 2,
                    ),
                  ),
                  child: Text(
                    badgeLabel,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onError,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class AppSegmentedControl<T> extends StatelessWidget {
  const AppSegmentedControl({
    super.key,
    required this.values,
    required this.selected,
    required this.labelBuilder,
    required this.onSelected,
  });

  final List<T> values;
  final T selected;
  final String Function(T value) labelBuilder;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: colors.surfaceContainer,
        borderRadius: BorderRadius.circular(AppRadius.input),
      ),
      child: Row(
        children: values
            .map((value) {
              final active = value == selected;
              return Expanded(
                child: Semantics(
                  button: true,
                  selected: active,
                  child: Material(
                    color: active ? colors.surface : Colors.transparent,
                    borderRadius: BorderRadius.circular(13),
                    child: InkWell(
                      onTap: () => onSelected(value),
                      borderRadius: BorderRadius.circular(13),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 44),
                        child: Center(
                          child: Text(
                            labelBuilder(value),
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(
                                  color: active
                                      ? colors.onSurface
                                      : colors.onSurfaceVariant,
                                  fontWeight: active
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            })
            .toList(growable: false),
      ),
    );
  }
}

class AppPageHeader extends StatelessWidget {
  const AppPageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final heading = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.headlineLarge),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
        ],
      ],
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final stack =
            trailing != null &&
            (constraints.maxWidth < 340 ||
                MediaQuery.textScalerOf(context).scale(1) > 1.35);
        if (stack) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              heading,
              const SizedBox(height: AppSpacing.sm),
              Align(alignment: Alignment.centerRight, child: trailing!),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: heading),
            if (trailing != null) ...[
              const SizedBox(width: AppSpacing.sm),
              trailing!,
            ],
          ],
        );
      },
    );
  }
}

class AppDetailHeader extends StatelessWidget {
  const AppDetailHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.onBack,
  });

  final String title;
  final String? subtitle;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      IconButton.filledTonal(
        onPressed: onBack ?? () => Navigator.maybePop(context),
        tooltip: 'Kembali',
        icon: const Icon(Icons.arrow_back_rounded),
      ),
      const SizedBox(width: AppSpacing.sm),
      Expanded(
        child: AppPageHeader(title: title, subtitle: subtitle),
      ),
    ],
  );
}

class AppIconTile extends StatelessWidget {
  const AppIconTile({
    super.key,
    required this.icon,
    this.size = 34,
    this.iconSize = 16,
    this.foreground,
    this.background,
  });

  final IconData icon;
  final double size;
  final double iconSize;
  final Color? foreground;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background ?? colors.primaryContainer,
        borderRadius: BorderRadius.circular(size * 0.35),
      ),
      child: Icon(icon, size: iconSize, color: foreground ?? colors.primary),
    );
  }
}

class AppSectionLabel extends StatelessWidget {
  const AppSectionLabel(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 2, bottom: 10),
    child: Text(
      label.toUpperCase(),
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
        letterSpacing: 0.8,
        fontWeight: FontWeight.w500,
      ),
    ),
  );
}

class AppBottomSheetShell extends StatelessWidget {
  const AppBottomSheetShell({
    super.key,
    required this.title,
    required this.child,
    this.description,
    this.onClose,
  });

  final String title;
  final String? description;
  final Widget child;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.screenHorizontal,
        AppSpacing.xs,
        AppSpacing.screenHorizontal,
        AppSpacing.lg + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleLarge),
                    if (description != null) ...[
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        description!,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
              if (onClose != null)
                IconButton(
                  onPressed: onClose,
                  tooltip: 'Tutup',
                  icon: const Icon(Icons.close_rounded),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.65,
            ),
            child: SingleChildScrollView(child: child),
          ),
        ],
      ),
    ),
  );
}

class AppSkeletonBlock extends StatelessWidget {
  const AppSkeletonBlock({
    super.key,
    required this.semanticLabel,
    this.height = 16,
    this.width = double.infinity,
    this.radius = AppRadius.icon,
  });

  final String semanticLabel;
  final double height;
  final double width;
  final double radius;

  @override
  Widget build(BuildContext context) => Semantics(
    label: semanticLabel,
    child: ExcludeSemantics(
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    ),
  );
}
