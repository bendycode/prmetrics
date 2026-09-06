require 'rails_helper'
require 'rake'

RSpec.describe 'Rakefile', type: :task do
  it 'runs RuboCop before RSpec' do
    Rake.with_application do
      load Rails.root.join('Rakefile')

      expect(Rake::Task[:default].prerequisites).to eq(%w[rubocop spec])
    end
  end
end
