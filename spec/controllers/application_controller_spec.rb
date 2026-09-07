require 'rails_helper'

RSpec.describe ApplicationController do
  describe '#page_param' do
    it 'is the only place under app/ that reads params[:page]' do
      defining_file = Rails.root.join('app/controllers/application_controller.rb')
      offenders = Rails.root.glob('app/{controllers,views}/**/*.{rb,erb}')
                       .reject { |file| file == defining_file }
                       .select { |file| file.read.match?(/params\[['":]page['"]?\]/) }
                       .map { |file| file.relative_path_from(Rails.root).to_s }

      expect(offenders).to be_empty
    end
  end
end
