# Known flaky-test fingerprints

When a CI failure on a Dependabot PR matches one of these patterns, treat it as
a flake rather than a regression from the bump. Per the `separate_flake_fix_pr`
dial, propose a standalone flake-fix PR first.

Append new entries (newest at the bottom) whenever a genuine flake is identified
and fixed, so pattern-matching gets richer over time.

---

## Selenium stale-node error

- **Error signature:** `Selenium::WebDriver::Error::UnknownError: Node with given id does not belong to the document`
- **Typical trigger:** a content or field assertion right after a click that navigates (form submit, link to another page). Capybara finds a node on the old document, the navigation swaps the document, and the visibility check on that node fails. Chrome 152 reports the detached node as a generic `UnknownError`, which Capybara 3.40 does not retry, so `synchronize` re-raises instead of waiting.
- **Fix pattern:** wait on `expect(page).to have_current_path(...)` after each navigating click, before reading the new document. `current_url` touches no node, so the wait closes the race. Then assert content only the expected branch renders (a flash notice), so a failed submit fails informatively.
- **Does not work:** a settling assertion before the click (`have_checked_field`, `have_field(..., with:)`). Tried 2026-04-17; the race is after the click, not before it.
- **First observed:** 2026-04-17 -- `spec/system/user_role_authorization_spec.rb` invite-admin spec. Root cause found 2026-09-04 from the failure screenshot showing the post-redirect page.

## Single Selenium system-spec timeout / missing content

- **Error signature:** `have_content` / `page.html include(...)` fails on one spec with a diff showing partial markup, or expected text reported "found using case-insensitive search" / "found including non-visible text"
- **Typical trigger:** assertion fires too early after `visit`, or uses `page.html` which bypasses Capybara's wait loop, or mismatches CSS `text-transform` on the rendered text
- **Fix pattern:** use Capybara's waiting matchers; for CSS-transformed text, use a case-insensitive regex (`have_content(/administration/i)`)
- **First observed:** 2026-04-17 -- `spec/system/user_role_authorization_spec.rb` admin-section spec
