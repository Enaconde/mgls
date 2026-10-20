import 'package:flutter/material.dart';

import '../../../core/places.dart';
import '../../../l10n/app_localizations.dart';
import '../../../theme/app_theme.dart';

class PickupStep extends StatelessWidget {
  const PickupStep({super.key, required this.onConfirm});

  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return _PointStep(
      title: l10n.pickupTitle,
      button: l10n.pickupConfirm,
      onConfirm: onConfirm,
    );
  }
}

class DropoffStep extends StatelessWidget {
  const DropoffStep({
    super.key,
    required this.onConfirm,
    required this.onRestart,
    required this.onPlace,
  });

  final VoidCallback onConfirm;
  final VoidCallback onRestart;
  final ValueChanged<Place> onPlace;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return _PointStep(
      title: l10n.dropoffTitle,
      button: l10n.dropoffConfirm,
      onConfirm: onConfirm,
      extra: [
        const SizedBox(height: AppSpacing.unit),
        Text(
          l10n.popularPlaces,
          style: Theme.of(context).textTheme.labelMedium,
        ),
        const SizedBox(height: AppSpacing.unit),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final place in popularPlaces(l10n))
                Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.unit),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      minHeight: AppSpacing.tapTarget,
                    ),
                    child: ActionChip(
                      avatar: Icon(
                        _placeIcon(place.kind),
                        size: AppSpacing.icon,
                      ),
                      label: Text(place.name),
                      onPressed: () => onPlace(place),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
      footer: TextButton(onPressed: onRestart, child: Text(l10n.restart)),
    );
  }
}

class _PointStep extends StatelessWidget {
  const _PointStep({
    required this.title,
    required this.button,
    required this.onConfirm,
    this.extra = const [],
    this.footer,
  });

  final String title;
  final String button;
  final VoidCallback onConfirm;
  final List<Widget> extra;
  final Widget? footer;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(title, style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: AppSpacing.unit),
      Text(AppLocalizations.of(context)!.moveMapHint),
      ...extra,
      const SizedBox(height: AppSpacing.page),
      FilledButton(onPressed: onConfirm, child: Text(button)),
      ?footer,
    ],
  );
}

IconData _placeIcon(PlaceKind kind) => switch (kind) {
  PlaceKind.market => Icons.storefront,
  PlaceKind.hospital => Icons.local_hospital,
  PlaceKind.transport => Icons.directions_bus,
  PlaceKind.school => Icons.school,
  PlaceKind.government => Icons.account_balance,
  PlaceKind.shopping => Icons.shopping_bag,
  PlaceKind.other => Icons.place,
};
