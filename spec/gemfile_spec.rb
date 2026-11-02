require 'bundler'

# Bundler only applies a Gemfile requirement when it resolves. A lockfile merged
# from a branch cut before the requirement existed installs and boots with a
# version the Gemfile forbids.
RSpec.describe 'Gemfile' do
  it 'has every gem it names locked within its requirement' do
    locked = Bundler.locked_gems.specs
    violations = Bundler.definition.dependencies.flat_map do |dependency|
      locked.select { |spec| spec.name == dependency.name }
            .reject { |spec| dependency.requirement.satisfied_by?(spec.version) }
            .map { |spec| "#{spec.name} #{spec.version} is outside #{dependency.requirement}" }
    end

    expect(violations).to be_empty
  end
end
