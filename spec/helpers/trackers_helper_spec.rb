require 'rails_helper'

RSpec.describe TrackersHelper do
  describe '#cycle_days' do
    # GitHub's times are whole seconds, so a cycle can fall seconds short of an hour
    it 'rounds a cycle to the minute before writing it out' do
      expect(helper.cycle_days(3 - (20.0 / 86_400))).to eq('3 days')
    end

    it 'writes days, hours, and minutes' do
      expect(helper.cycle_days(1 + (90.0 / 1440))).to eq('1 day, 1 hour, 30 minutes')
    end
  end
end
