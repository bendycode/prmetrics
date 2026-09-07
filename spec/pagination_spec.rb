require 'rails_helper'

RSpec.describe 'Pagination' do
  # Source text with Ruby comment lines and ERB comments removed, keyed by
  # path, so a comment that mentions params[:page] does not read as a caller.
  let(:sources) do
    Rails.root.glob('app/**/*.{rb,erb}').to_h do |file|
      code = file.read.lines.reject { |line| line.lstrip.start_with?('#') }.join.gsub(/<%#.*?%>/m, '')
      [file.relative_path_from(Rails.root).to_s, code]
    end
  end

  it 'reads params[:page] only in ApplicationController#page_param' do
    readers = sources.select { |_, code| code.match?(/params(\[|\.(fetch|dig|permit|require)\()\s*['":]page\b/) }

    expect(readers.keys).to contain_exactly('app/controllers/application_controller.rb')
  end

  it 'passes page_param to every .page call' do
    raw_callers = sources.select { |_, code| code.match?(/\.page\((?!page_param\))/) }

    expect(raw_callers.keys).to be_empty
  end
end
