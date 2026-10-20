# Prompt to paste into Codex (ChatGPT)

Open the folder `C:\Users\bayrtbaatar\Desktop\mgl-cab` as the project in
Codex, then paste the prompt below. Paste the same prompt again for each
next milestone.

```text
You are building MGLS, a Flutter taxi app for Erdenet, Mongolia.

1. Read AGENTS.md completely and follow it exactly.
2. Read docs/ROADMAP.md, then all of docs/PROGRESS.md (especially every
   "Lessons for next runs" section).
3. Find the first milestone in docs/ROADMAP.md that PROGRESS.md does not mark
   as verified. Do that one milestone only: every Build item, and meet every
   Done-when item.
4. Skip any part that needs the owner (accounts, money, legal answers, real
   phones). Write it under "Blocked on owner" in PROGRESS.md and keep going
   with the rest.
5. Before you finish, run these inside rider_app with the full Flutter path
   from AGENTS.md: `flutter gen-l10n`, `flutter analyze` (must say No issues
   found) and `flutter test` (all must pass). Fix what fails. If you cannot run
   Flutter, say so clearly and do not mark the milestone verified.
6. Check new screens in light AND dark mode and with 1.3x text size. Text
   must be readable on its background (theme_test.dart checks contrast).
7. Every new user-facing text goes into both lib/l10n/app_mn.arb and
   app_en.arb. Never hard-code Mongolian text in widgets.
8. Never commit secrets, never push, never create accounts, never change
   Windows settings. Never copy code or assets from other taxi or map apps.
9. Finish by appending a PROGRESS.md entry: date, milestone, what changed,
   how you verified it (paste the analyze and test result lines), what is
   left, what is blocked on the owner, and lessons for the next run. In your
   final message list every file you created, moved or deleted.
```

## After each run, check yourself

- The PROGRESS.md entry says `No issues found` and `All tests passed`.
- Run the app: `C:\Users\bayrtbaatar\dev\flutter\bin\flutter.bat run -d chrome`
  inside `rider_app`, and try the new screens.
- If something broke, the last verified copy is
  `C:\Users\bayrtbaatar\Desktop\mgl-cab-backup-2026-10-20` (before M1).
  Make your own copy of `mgl-cab` after each good milestone.
