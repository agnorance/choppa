---
name: ship
description: Finish a change in choppa - run tests, update docs, commit without AI attribution, push to the working branch and check CI. Use whenever a piece of work is done or the owner says to commit or push.
---

# Shipping a change

1. **Re-import and test.** `tools/test.ps1` (Windows) or `tools/test.sh`; it must end
   with `ALL TESTS PASSED`. New behaviour gets a test in `tests/run_tests.gd` (add it to
   the list at the top).
2. **Look** at a screenshot if anything visual changed (`screenshot` skill).
3. **Docs:** docs/DESIGN.md (what exists, what's next), README.md (controls, modes,
   items, arguments), CLAUDE.md (commands, rules) when they are affected. The argument
   list at the top of `scripts/main.gd` when you add one.
4. **Commit:** on the working branch (`godot-foundation`), never main unless asked.
   Message: a short summary line, a blank line, then what changed and why in plain
   prose. **No AI attribution** (no Co-Authored-By or similar lines). Include
   generated assets and their `.import` / `.uid` files; never commit `.godot/` or
   `build/`.
5. **Push:** `git push -u origin <branch>`; on network errors retry a few times.
6. **CI:** `gh run list -R agnorance/choppa -b <branch> -L 1`, then
   `gh run watch <id> -R agnorance/choppa --exit-status`. If it fails, read the
   annotations (`gh api repos/agnorance/choppa/check-runs/<id>/annotations`); fix and
   push again.
7. **Report** to the owner what changed, what they should try on their PC/phone, and
   anything not verified.
