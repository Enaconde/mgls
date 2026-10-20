import 'package:flutter_test/flutter_test.dart';
import 'package:rider_app/core/money.dart';
import 'package:rider_app/l10n/app_localizations_en.dart';

void main() {
  test('formatMnt adds thousands separators and the tugrik sign', () {
    expect(formatMnt(900), '900₮');
    expect(formatMnt(3000), '3,000₮');
    expect(formatMnt(12500), '12,500₮');
    expect(formatMnt(1250000), '1,250,000₮');
  });

  test('money handles zero, grouping boundaries and negative values', () {
    expect(formatMnt(0), '0₮');
    expect(formatMnt(999), '999₮');
    expect(formatMnt(1000), '1,000₮');
    expect(formatMnt(1000000), '1,000,000₮');
    expect(formatMnt(-1000), '-1,000₮');
    expect(formatMnt(12500, l10n: AppLocalizationsEn()), '12,500₮');
  });
}
