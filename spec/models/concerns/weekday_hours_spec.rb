require 'rails_helper'

RSpec.describe WeekdayHours do
  let(:dummy_class) do
    Class.new do
      include WeekdayHours
    end
  end

  describe '.weekday_hours_between' do
    context 'when start and end times are on the same weekday' do
      it 'calculates hours correctly' do
        # Monday
        start_time = Time.zone.local(2024, 1, 8, 9, 0, 0)
        end_time = Time.zone.local(2024, 1, 8, 17, 0, 0)

        hours = dummy_class.weekday_hours_between(start_time, end_time)
        # Expect 8 hours since it's the same day
        expect(hours).to eq(8.0)
      end
    end

    context 'when start and end times span multiple weekdays' do
      it 'calculates hours correctly' do
        # Monday to Wednesday
        start_time = Time.zone.local(2024, 1, 8, 9, 0, 0)
        end_time = Time.zone.local(2024, 1, 10, 17, 0, 0)

        hours = dummy_class.weekday_hours_between(start_time, end_time)
        # Monday (15 hours: 9am to midnight) + Tuesday (24 hours) + Wednesday (17 hours: midnight to 5pm)
        expect(hours).to eq(15 + 24 + 17)
      end
    end

    context 'when time span includes weekends' do
      it 'excludes weekend hours' do
        # Friday to Monday
        start_time = Time.zone.local(2024, 1, 5, 9, 0, 0)
        end_time = Time.zone.local(2024, 1, 8, 17, 0, 0)

        hours = dummy_class.weekday_hours_between(start_time, end_time)
        # Friday (15 hours: 9am to midnight) + Monday (17 hours: midnight to 5pm)
        expect(hours).to eq(15 + 17)
      end
    end

    context 'when time span starts on weekend' do
      it 'starts counting from Monday' do
        # Saturday to Tuesday
        start_time = Time.zone.local(2024, 1, 6, 9, 0, 0) # Saturday
        end_time = Time.zone.local(2024, 1, 9, 17, 0, 0)  # Tuesday

        hours = dummy_class.weekday_hours_between(start_time, end_time)
        # Monday (24 hours) + Tuesday (17 hours: midnight to 5pm)
        expect(hours).to eq(24 + 17)
      end
    end

    context 'when time span ends on weekend' do
      it 'only counts until Friday' do
        # Thursday to Saturday
        start_time = Time.zone.local(2024, 1, 4, 9, 0, 0) # Thursday
        end_time = Time.zone.local(2024, 1, 6, 17, 0, 0)  # Saturday

        hours = dummy_class.weekday_hours_between(start_time, end_time)
        # Thursday (15 hours: 9am to midnight) + Friday (24 hours)
        expect(hours).to eq(15 + 24)
      end
    end

    context 'with edge cases' do
      it 'returns 0 if start_time is after end_time' do
        start_time = Time.zone.local(2024, 1, 8, 17, 0, 0)
        end_time = Time.zone.local(2024, 1, 8, 9, 0, 0)

        hours = dummy_class.weekday_hours_between(start_time, end_time)
        expect(hours).to eq(0)
      end

      it 'returns 0 if start_time equals end_time' do
        time = Time.zone.local(2024, 1, 8, 9, 0, 0)

        hours = dummy_class.weekday_hours_between(time, time)
        expect(hours).to eq(0)
      end

      it 'returns 0 if either time is nil' do
        valid_time = Time.zone.local(2024, 1, 8, 9, 0, 0)

        expect(dummy_class.weekday_hours_between(nil, valid_time)).to eq(0)
        expect(dummy_class.weekday_hours_between(valid_time, nil)).to eq(0)
        expect(dummy_class.weekday_hours_between(nil, nil)).to eq(0)
      end
    end
  end
end
