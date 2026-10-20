import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../theme/app_theme.dart';

class MapControls extends StatelessWidget {
  const MapControls({
    super.key,
    required this.is3d,
    required this.onToggle3d,
    required this.onLocate,
  });

  final bool is3d;
  final VoidCallback onToggle3d;
  final VoidCallback onLocate;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      children: [
        _MapButton(
          label: is3d ? l10n.show2d : l10n.show3d,
          onPressed: onToggle3d,
          child: Text(
            is3d ? l10n.map2d : l10n.map3d,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(height: AppSpacing.unit),
        _MapButton(
          label: l10n.locate,
          onPressed: onLocate,
          child: const Icon(Icons.my_location, size: AppSpacing.icon),
        ),
      ],
    );
  }
}

class _MapButton extends StatelessWidget {
  const _MapButton({
    required this.label,
    required this.onPressed,
    required this.child,
  });

  final String label;
  final VoidCallback onPressed;
  final Widget child;

  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surface,
    elevation: 3,
    shape: const CircleBorder(),
    child: Tooltip(
      message: label,
      child: Semantics(
        label: label,
        button: true,
        excludeSemantics: true,
        onTap: onPressed,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox.square(
            dimension: AppSpacing.tapTarget,
            child: Center(child: child),
          ),
        ),
      ),
    ),
  );
}
