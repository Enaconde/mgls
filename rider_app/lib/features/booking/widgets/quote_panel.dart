import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/backend.dart';
import '../../../data/backend_config.dart';
import '../../../l10n/app_localizations.dart';
import '../../../theme/app_theme.dart';
import '../booking_controller.dart';
import '../booking_provider.dart';
import 'price_card.dart';

class QuotePanel extends ConsumerWidget {
  const QuotePanel({
    super.key,
    required this.booking,
    required this.onOrder,
    required this.onRestart,
  });
  final BookingState booking;
  final VoidCallback onOrder;
  final VoidCallback onRestart;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final notifier = ref.read(bookingProvider.notifier);
    final catalog = ref.watch(fareCatalogProvider).asData?.value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (booking.quoting) ...[
          LinearProgressIndicator(semanticsLabel: l10n.loadingFare),
          const SizedBox(height: AppSpacing.unit),
          Text(l10n.loadingFare),
        ] else if (booking.quoteFailed || booking.quote == null) ...[
          Text(
            l10n.fareUnavailable,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Text(l10n.fareRetryHint),
          FilledButton(onPressed: notifier.retryQuote, child: Text(l10n.retry)),
        ] else ...[
          if (catalog != null) ...[
            Text(
              l10n.companyLabel,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (booking.stage == BookingStage.requested)
              Text(
                catalog.companies
                        .where((c) => c.id == booking.companyId)
                        .firstOrNull
                        ?.name ??
                    l10n.companyLabel,
              )
            else
              Wrap(
                spacing: AppSpacing.unit,
                children: [
                  for (final company in catalog.companies)
                    ChoiceChip(
                      label: DefaultTextStyle(
                        style: Theme.of(context).textTheme.labelLarge!.copyWith(
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                        softWrap: true,
                        child: Text(company.name),
                      ),
                      selected: booking.companyId == company.id,
                      onSelected: (_) =>
                          notifier.retryQuote(companyId: company.id),
                    ),
                ],
              ),
          ],
          if (ref.watch(backendProvider).mode == BackendMode.supabase)
            Text(l10n.liveQuoteNotice),
          const SizedBox(height: AppSpacing.unit),
          PriceCard(
            booking: booking,
            onOffer: notifier.setOffer,
            onOrder: onOrder,
            onRestart: onRestart,
          ),
        ],
        if (booking.quote == null)
          TextButton(onPressed: onRestart, child: Text(l10n.restart)),
      ],
    );
  }
}
