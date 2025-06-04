# Code Coverage

This project uses SimpleCov with ratcheting to ensure code coverage never decreases.

## Current Status

- **Current Coverage**: 77.87%
- **Baseline**: 77.87%
- **Target**: Gradual improvement through ratcheting

## Usage

### Running Tests with Coverage

```bash
# Run tests with coverage report
bundle exec rspec

# Check coverage status
bundle exec rake coverage:status

# Show coverage trend
bundle exec rake coverage:trend
```

### Ratcheting System

The ratcheting system prevents coverage regression:

```bash
# Run ratcheting check (used in CI)
bundle exec rake coverage:ratchet

# Update baseline to current coverage
bundle exec rake coverage:update_baseline
```

### CI Integration

Coverage is checked automatically in CI:

```bash
# Run all CI checks (coverage + data integrity)
bundle exec rake ci:all

# Run just coverage check
bundle exec rake ci:coverage_check
```

## How It Works

1. **Baseline Tracking**: The `.coverage_baseline` file tracks the minimum acceptable coverage
2. **Automatic Ratcheting**: When coverage improves, the baseline automatically updates
3. **Regression Prevention**: Coverage cannot decrease below the baseline
4. **CI Enforcement**: The CI pipeline fails if coverage drops

## Coverage Goals

- **Short-term**: Maintain current coverage (77.87%)
- **Medium-term**: Reach 85% through incremental improvements
- **Long-term**: Achieve 90%+ coverage

## Files

- `.coverage_baseline` - Current coverage baseline (tracked in git)
- `coverage/` - Generated coverage reports (gitignored)
- `spec/rails_helper.rb` - SimpleCov configuration
- `lib/tasks/coverage*.rake` - Coverage rake tasks