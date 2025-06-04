namespace :coverage do
  desc "Run tests with coverage and check against baseline"
  task :check do
    ENV['COVERAGE'] = 'true'
    
    # Run RSpec with coverage
    system("bundle exec rspec")
    
    # Check if coverage met the minimum threshold
    exit_code = $?.exitstatus
    if exit_code != 0
      puts "\n❌ Tests failed or coverage below minimum threshold"
      exit(exit_code)
    else
      puts "\n✅ All tests passed and coverage meets minimum threshold"
    end
  end
  
  desc "Update coverage baseline file"
  task :update_baseline do
    baseline_file = Rails.root.join('.coverage_baseline')
    coverage_file = Rails.root.join('coverage/.last_run.json')
    
    if File.exist?(coverage_file)
      coverage_data = JSON.parse(File.read(coverage_file))
      current_coverage = coverage_data['result']['line']&.round(2)
      
      if current_coverage
        File.write(baseline_file, current_coverage.to_s)
        puts "✅ Coverage baseline updated to #{current_coverage}%"
      else
        puts "❌ Could not extract coverage percentage from coverage report"
      end
    else
      puts "❌ Coverage file not found. Run 'rake coverage:check' first."
    end
  end
  
  desc "Show current coverage and baseline"
  task :status do
    baseline_file = Rails.root.join('.coverage_baseline')
    coverage_file = Rails.root.join('coverage/.last_run.json')
    
    baseline = File.exist?(baseline_file) ? File.read(baseline_file).to_f : nil
    
    if File.exist?(coverage_file)
      coverage_data = JSON.parse(File.read(coverage_file))
      current_coverage = coverage_data['result']['line']&.round(2)
      
      puts "\n📊 Coverage Status:"
      puts "   Current coverage: #{current_coverage}%"
      puts "   Baseline coverage: #{baseline ? "#{baseline}%" : 'Not set'}"
      
      if baseline && current_coverage
        diff = (current_coverage - baseline).round(2)
        if diff > 0
          puts "   Change: +#{diff}% ✅"
        elsif diff < 0
          puts "   Change: #{diff}% ⚠️"
        else
          puts "   Change: 0% ➖"
        end
      end
    else
      puts "\n❌ No coverage data found. Run 'rake coverage:check' first."
    end
  end
end

# Add coverage ratcheting to CI
task ci: ['coverage:ratchet']