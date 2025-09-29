# Pull Request

## Issue Link

<!-- Example: [Linear issue MME-225](https://linear.app/bendyworks/issue/MME-225/only-admin-can-change-stem-challenge) -->

## Summary

### What changed?
<!-- Brief description of the changes made -->

### Why was this change needed?
<!-- Context for why these changes were necessary -->

### Any architectural decisions?
<!-- Note any significant design or architecture choices -->

## Quality Checklist ✅

### Code Quality (Required - Zero Tolerance)
- [ ] `bundle exec rake` completes successfully
- [ ] No trailing whitespace in any files
- [ ] **No `rubocop:disable` comments added** (fix the underlying issue instead)

### Testing Coverage
- [ ] Added appropriate tests (unit/integration/system as needed)
- [ ] For UI features: system tests with `js: true` included for real browser testing
- [ ] Test coverage maintained or improved
- [ ] Edge cases and error conditions tested
- [ ] Integration tests prioritized over unit tests for UI features

### Rails & Architecture
- [ ] Follows Rails idioms and conventions
- [ ] Uses Rails built-in features (enums, scopes, callbacks, validations, etc.)
- [ ] Service objects used for complex business logic instead of fat models/controllers
- [ ] Proper ActiveRecord associations with standard foreign key naming (`table_id`)
- [ ] Database schema changes include safe migrations
- [ ] Uses symbols for enum values (not magic numbers)

### Security & Best Practices
- [ ] No secrets, credentials, or API keys committed
- [ ] Proper authorization with Pundit policies if user-facing
- [ ] SQL injection prevention considered (use ActiveRecord methods)
- [ ] Input validation and sanitization implemented
- [ ] Session management follows security best practices

### PR Size & Organization
- [ ] PR focused on single concern/feature
- [ ] Changes are <300 lines when possible (suggest splitting if larger)
- [ ] Related changes grouped logically in commits
- [ ] Commit messages follow project conventions

### Documentation & Deployment
- [ ] Code changes documented where needed (complex business logic)
- [ ] Database migrations are production-safe (no blocking operations)
- [ ] No breaking changes to existing functionality
- [ ] New environment variables documented in PR description if added

## Test Plan

<!-- Describe how to test these changes -->
- [ ] Manual testing steps completed
- [ ] Automated tests cover the changes
- [ ] Tested in different user roles (admin/regular user) if applicable

## Additional Notes

<!-- Any other information reviewers should know -->

---

**Reviewer Note**: This PR must pass all quality checks before approval. The "Clean and Green" philosophy means zero warnings/failures are acceptable.
