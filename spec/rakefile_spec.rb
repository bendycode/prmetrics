require 'rails_helper'
require 'open3'

RSpec.describe 'Rakefile', type: :task do
  # The Rakefile is read in a subprocess. Loading it in-process would pull
  # every lib/tasks file into the coverage report as uncovered lines.
  it 'runs RuboCop before RSpec' do
    listing, status = Open3.capture2e('bundle', 'exec', 'rake', '--prereqs', chdir: Rails.root)
    expect(status).to be_success, listing

    lines = listing.lines(chomp: true)
    after_default = lines.drop(lines.index('rake default') + 1)
    prerequisites = after_default.take_while { |line| line.start_with?('    ') }.map(&:strip)

    expect(prerequisites).to eq(%w[rubocop spec])
  end
end
