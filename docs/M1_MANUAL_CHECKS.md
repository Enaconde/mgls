# M1 verification still needed outside the sandbox

Run from `rider_app/` with the Flutter commands in the root README:

1. Run `flutter gen-l10n`, `flutter analyze` and `flutter test`. Require no
   analyzer issues and all tests passing. The widget tests inject a fake map
   and route loader; they must not need a network connection or a platform map.
2. Open the web app in a visible tab and reload it. Repeat the following on
   `mgls_pixel` started with `-gpu host`. Choose **No thanks** on Location
   Accuracy; never accept consent dialogs.
3. Check the unchanged vector map: Mongolian road labels, buildings, subtle
   center-zone outline, and visible OpenStreetMap attribution at the top left.
4. Move the map and confirm pickup. Check the circular pickup mark, square
   dropoff pin, popular places, and restart button. Restart must clear marks.
5. Choose a popular place or confirm the map center as dropoff. Check that the
   route starts as a straight line, then follows roads when OSRM responds.
   The distance/time should update without changing the quoted fare.
6. Test both points inside the town and outside the center: fixed `3,000₮`.
   Test one point inside the center or outside town: offer slider stays inside
   the displayed tariff range, with the same initial suggested fare as before.
7. Tap Book: show the existing demo/server-not-connected notice. Repeated
   notices and editing the offer still work. Restart returns to pickup.
8. Toggle 3D and locate. After a route fit, the button must offer 3D again.
   Deny app location permission and confirm that the Erdenet fallback works.
9. Disconnect the network before choosing dropoff: keep the quote and straight
   route fallback. Restart while a route loads and reselect the same points;
   a response for the old trip must not attach to the new trip.
10. Check system light/dark appearances and 1.3× text scaling at narrow phone
    width. Text must wrap, popular places scroll horizontally, and a tall
    bottom card scroll vertically. Icon controls have Mongolian semantics and
    at least 48 dp targets. Inspect with a screen reader where available.

The app defaults to Mongolian. English copy and place labels are exercised by
the widget tests using `RiderApp(locale: Locale('en'))`. No language selection
screen is added in M1.
