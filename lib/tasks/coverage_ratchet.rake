namespace :coverage do
  desc 'Run ratcheting coverage check'
  task :ratchet do
    require 'json'

    baseline_file = Rails.root.join('.coverage_baseline')
    coverage_file = Rails.root.join('coverage/.last_run.json')

    # Ensure we have a baseline
    unless File.exist?(baseline_file)
      puts '⚠️  No coverage baseline found. Creating one...'
      Rake::Task['coverage:update_baseline'].invoke
      exit(0)
    end

    # Run tests with coverage
    puts '🧪 Running tests with coverage...'
    system('bundle exec rspec --format progress')
    test_exit_code = $?.exitstatus

    # If tests failed, exit early
    if test_exit_code != 0
      puts "\n❌ Tests failed!"
      exit(test_exit_code)
    end

    # Check coverage
    if File.exist?(coverage_file)
      coverage_data = JSON.parse(File.read(coverage_file))
      current_coverage = coverage_data['result']['line']&.round(2)
      baseline_coverage = File.read(baseline_file).to_f

      puts "\n📊 Coverage Report:"
      puts "   Current:  #{current_coverage}%"
      puts "   Baseline: #{baseline_coverage}%"

      if current_coverage < baseline_coverage
        diff = (baseline_coverage - current_coverage).round(2)
        puts "\n❌ Coverage decreased by #{diff}%!"
        puts '   Coverage must not decrease below the baseline.'
        exit(1)
      elsif current_coverage > baseline_coverage
        diff = (current_coverage - baseline_coverage).round(2)
        puts "\n✅ Coverage increased by #{diff}%!"

        # Update SimpleCov minimum coverage in rails_helper
        rails_helper = Rails.root.join('spec/rails_helper.rb')
        content = File.read(rails_helper)
        updated_content = content.gsub(/minimum_coverage \d+\.?\d*/, "minimum_coverage #{current_coverage}")
        File.write(rails_helper, updated_content)

        # Update baseline
        File.write(baseline_file, current_coverage.to_s)
        puts "   Baseline updated to #{current_coverage}%"
      else
        puts "\n✅ Coverage maintained at #{current_coverage}%"
      end
    else
      puts "\n❌ Coverage file not found!"
      exit(1)
    end
  end

  desc 'Show coverage trend'
  task :trend do
    require 'json'

    baseline_file = Rails.root.join('.coverage_baseline')
    coverage_file = Rails.root.join('coverage/.last_run.json')

    if File.exist?(coverage_file) && File.exist?(baseline_file)
      coverage_data = JSON.parse(File.read(coverage_file))
      current = coverage_data['result']['line']&.round(2)
      baseline = File.read(baseline_file).to_f

      puts "\n📈 Coverage Trend:"
      puts '   Start:   77.87% (initial baseline)'
      puts "   Current: #{baseline}% (ratcheted baseline)"
      puts "   Latest:  #{current}% (last run)"

      overall_improvement = (baseline - 77.87).round(2)
      puts "\n   Total improvement: +#{overall_improvement}% 🎉" if overall_improvement > 0
    else
      puts "\n❌ Missing coverage data. Run tests first."
    end
  end
end
