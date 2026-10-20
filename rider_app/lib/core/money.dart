import 'package:intl/intl.dart';

import '../l10n/app_localizations.dart';
import '../l10n/app_localizations_mn.dart';

/// Whole tugrik with stable grouping, e.g. 12,500₮ in either locale.
String formatMnt(int mnt, {AppLocalizations? l10n}) =>
    (l10n ?? AppLocalizationsMn()).moneyAmount(
      NumberFormat('#,##0', 'en').format(mnt),
    );
