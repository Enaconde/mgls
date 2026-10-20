import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../theme/app_theme.dart';

class CenterPin extends StatelessWidget {
  const CenterPin({super.key, required this.isPickup});

  final bool isPickup;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final shape = isPickup ? BoxShape.circle : BoxShape.rectangle;
    return IgnorePointer(
      child: Center(
        child: Semantics(
          label: isPickup ? l10n.pickupPin : l10n.dropoffPin,
          child: Transform.translate(
            offset: const Offset(0, -19),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: AppColors.ink,
                    shape: shape,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: const [
                      BoxShadow(blurRadius: 4, color: Colors.black26),
                    ],
                  ),
                  child: Center(
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: shape,
                      ),
                    ),
                  ),
                ),
                Container(width: 2, height: 16, color: AppColors.ink),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
