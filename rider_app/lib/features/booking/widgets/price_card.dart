import 'package:flutter/material.dart';

import '../../../core/money.dart';
import '../../../l10n/app_localizations.dart';
import '../../../theme/app_theme.dart';
import '../booking_controller.dart';

class PriceCard extends StatelessWidget {
  const PriceCard({
    super.key,
    required this.booking,
    required this.onOffer,
    required this.onOrder,
    required this.onRestart,
  });

  final BookingState booking;
  final ValueChanged<int> onOffer;
  final VoidCallback onOrder;
  final VoidCallback onRestart;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final quote = booking.quote!;
    final scheme = Theme.of(context).colorScheme;
    final route = booking.route;
    final km = ((route?.distanceM ?? quote.distanceM) / 1000).toStringAsFixed(
      1,
    );
    String money(int amount) => formatMnt(amount, l10n: l10n);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: AppSpacing.unit,
          children: [
            Chip(
              label: Text(quote.isFlat ? l10n.flatFare : l10n.normalTaxi),
              backgroundColor: scheme.secondaryContainer,
              labelStyle: TextStyle(color: scheme.onSecondaryContainer),
            ),
            Text(
              l10n.routeTaxiSoon,
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.page),
        Text(
          route == null
              ? l10n.approximateDistance(km)
              : l10n.routeSummary(km, (route.durationS / 60).ceil()),
        ),
        const SizedBox(height: AppSpacing.unit),
        if (quote.isFlat)
          Text(
            l10n.townFlatPrice(money(quote.suggestedMnt)),
            style: Theme.of(context).textTheme.titleLarge,
          )
        else ...[
          Text(
            l10n.yourOffer(money(booking.offerMnt!)),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          Semantics(
            label: l10n.offerLabel,
            child: Slider(
              value: booking.offerMnt!.toDouble(),
              min: quote.minMnt.toDouble(),
              max: quote.maxMnt.toDouble(),
              divisions: ((quote.maxMnt - quote.minMnt) ~/ 100).clamp(1, 1000),
              onChanged: quote.minMnt == quote.maxMnt
                  ? null
                  : (value) => onOffer(value.round()),
              semanticFormatterCallback: (value) => money(value.round()),
            ),
          ),
          Text(l10n.allowedPrice(money(quote.minMnt), money(quote.maxMnt))),
        ],
        const SizedBox(height: AppSpacing.page),
        FilledButton(onPressed: onOrder, child: Text(l10n.order)),
        TextButton(onPressed: onRestart, child: Text(l10n.restart)),
      ],
    );
  }
}
