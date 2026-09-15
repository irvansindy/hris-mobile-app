import 'package:flutter/material.dart';

import 'package:hrm_app/core/theme/app_theme.dart';
import 'package:hrm_app/core/widgets/app_components.dart';

enum AppViewStateKind { loading, empty, error, offline, permission }

class AppStateView extends StatelessWidget {
  const AppStateView({
    super.key,
    required this.kind,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  }) : assert((actionLabel == null) == (onAction == null));

  const AppStateView.loading({
    super.key,
    required this.title,
    required this.message,
  }) : kind = AppViewStateKind.loading,
       actionLabel = null,
       onAction = null;

  final AppViewStateKind kind;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  IconData get _icon => switch (kind) {
    AppViewStateKind.loading => Icons.sync_rounded,
    AppViewStateKind.empty => Icons.inbox_outlined,
    AppViewStateKind.error => Icons.error_outline_rounded,
    AppViewStateKind.offline => Icons.cloud_off_outlined,
    AppViewStateKind.permission => Icons.lock_outline_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isLive =
        kind == AppViewStateKind.loading ||
        kind == AppViewStateKind.error ||
        kind == AppViewStateKind.offline;
    return Semantics(
      container: true,
      liveRegion: isLive,
      label: '$title. $message',
      child: AppSurfaceCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (kind == AppViewStateKind.loading)
              const SizedBox.square(
                dimension: 28,
                child: AppLoadingIndicator(strokeWidth: 2.5),
              )
            else
              Icon(_icon, size: 32, color: colors.primary),
            const SizedBox(height: AppSpacing.sm),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (onAction != null) ...[
              const SizedBox(height: AppSpacing.md),
              OutlinedButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
