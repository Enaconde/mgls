import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../map_adapter.dart';

class BookingMapView extends StatelessWidget {
  const BookingMapView({
    super.key,
    required this.adapter,
    required this.onReady,
  });

  final MapAdapter adapter;
  final VoidCallback onReady;

  @override
  Widget build(BuildContext context) => Semantics(
    label: AppLocalizations.of(context)!.mapLabel,
    child: adapter.buildView(
      onReady: onReady,
      devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
    ),
  );
}
