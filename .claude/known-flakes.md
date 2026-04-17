# Known flaky-test fingerprints

When a CI failure on a Dependabot PR matches one of these patterns, treat it as
a flake rather than a regression from the bump. Per the `separate_flake_fix_pr`
dial, propose a standalone flake-fix PR first.

Append new entries (newest at the bottom) whenever a genuine flake is identified
and fixed, so pattern-matching gets richer over time.

---

## Selenium stale-node error

- **Error signature:** `Selenium::WebDriver::Error::UnknownError: Node with given id does not belong to the document`
- **Typical trigger:** `click_button`, `visible?`, or other element interaction after a prior step, often with Turbo/Bootstrap JS still settling
- **Fix pattern:** add a settling assertion between interactions (e.g. `expect(page).to have_checked_field(...)`, `have_field(..., with: value)`) so Capybara waits before the element handle is reused
- **First observed:** 2026-04-17 -- `spec/system/user_role_authorization_spec.rb` invite-admin spec

## Single Selenium system-spec timeout / missing content

- **Error signature:** `have_content` / `page.html include(...)` fails on one spec with a diff showing partial markup, or expected text reported "found using case-insensitive search" / "found including non-visible text"
- **Typical trigger:** assertion fires too early after `visit`, or uses `page.html` which bypasses Capybara's wait loop, or mismatches CSS `text-transform` on the rendered text
- **Fix pattern:** use Capybara's waiting matchers; for CSS-transformed text, use a case-insensitive regex (`have_content(/administration/i)`)
- **First observed:** 2026-04-17 -- `spec/system/user_role_authorization_spec.rb` admin-section spec
