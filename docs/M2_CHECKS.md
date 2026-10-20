# M2 — search and places checks

Scope: M2 only. M1 was marked verified in PROGRESS.md before this run.

## Automated acceptance checks

- `geocoder_test.dart`: concurrent requests and HTTP failures keep at least
  1,000 ms between request starts, normalized queries and duplicate concurrent
  submissions hit the cache, locale keys differ, short queries do not request,
  retry after network/malformed JSON failure works. Parser checks Erdenet bounds,
  name + area, duplicate OSM IDs and category icons.
- `place_store_test.dart`: last ten unique recents, immutable snapshots, Home
  and Work replacement, report note/time/coordinates, real shared_preferences
  mock reload and corrupt-storage preservation.
- `place_search_widget_test.dart`: offline popular/saved/recent results in
  order; typing sends zero online requests; explicit submit, loading, empty,
  network error, stale response rejection; storage loading/error/retry; saved
  Work survives search reopening; selected pickup/dropoff reach booking with
  the fake map; Home can be set by a confirmed map pin; reports save locally.
- Four locale/theme combinations at 320×700 dp, 1.3× text, covering search,
  saved-place setup, report form and a 220 dp keyboard inset.
- `theme_test.dart`: text and grey secondary text contrast >= 4.5 on surfaces
  and scaffold/dialog backgrounds, light and dark, plus button text; existing
  title contrast retained.
- Existing booking/controller/pricing/money/map seam tests remain in the suite.

Run commands and exact final result lines are recorded in PROGRESS.md.

## Visual QA

The optional capture run loads the installed SDK's Roboto and MaterialIcons
fonts in tests. PNGs are written under the ignored `screenshots/` directory.
Inspect `m2_light_results.png`, `m2_dark_results.png`, `m2_light_report.png`, and
`m2_dark_report.png`. They use Mongolian at 1.3× text, 320 dp width. The report
prompt is above the field so it wraps instead of truncating as an input label.
The map intentionally retains M1's light style; the new UI follows the theme.

## Optional live development lookup

Do not run public Nominatim autocomplete or bulk requests. For a single local
developer only, enable the README flag, submit an Erdenet landmark once, and
check that a name + area result appears. Search again to use the session cache.
Stop the server when done. All automated HTTP tests use fakes and generate no
public Nominatim traffic. Production geocoder provisioning is blocked on owner.

## OSM source audit for added landmarks

All coordinates are approximate centres. Individual source comments in
`rider_app/lib/core/places.dart` link to the OSM object and coordinate lookup:

- Polytechnic College: OSM node 8236874887, 49.02849, 104.06469.
- Emodin hospital: OSM node 10182533043, 49.03337, 104.05326.
- Administration building: OSM way 387786680, 49.02957, 104.06213.
  OSM labels this a town hall; no unsupported governor-office identity is used.
- Yeson Erdene market: OSM way 386659029, 49.02719, 104.06432.

The resulting catalogue has 16 places spanning markets, hospitals, schools,
government, stations and major shops. No third-party app code/assets were used.
