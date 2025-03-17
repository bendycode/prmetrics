module WeekdayHours
  extend ActiveSupport::Concern

  # Calculate weekday hours between two times, excluding weekends
  # Counts all 24 hours of weekdays (Monday through Friday)
  # Completely ignores weekends (Saturday and Sunday)
  def self.weekday_hours_between(start_time, end_time)
    return 0 if start_time.nil? || end_time.nil? || start_time >= end_time

    # If start_time is on a weekend, move to next Monday
    if start_time.saturday?
      start_time = start_time.next_occurring(:monday).beginning_of_day
    elsif start_time.sunday?
      start_time = start_time.next_occurring(:monday).beginning_of_day
    end

    # If end_time is on a weekend, move to previous Friday
    if end_time.saturday?
      end_time = end_time.prev_occurring(:friday).end_of_day
    elsif end_time.sunday?
      end_time = end_time.prev_occurring(:friday).end_of_day
    end

    # Return 0 if adjusted times are invalid
    return 0 if start_time >= end_time

    # Initialize hours
    weekday_hours = 0
    current_date = start_time.to_date
    end_date = end_time.to_date

    # Process each day
    while current_date <= end_date
      # Skip weekends
      if current_date.saturday? || current_date.sunday?
        current_date += 1.day
        next
      end

      # For the first day (start day)
      if current_date == start_time.to_date
        if current_date == end_time.to_date
          hours = (end_time - start_time) / 1.hour
        else
          day_end = current_date.end_of_day
          hours = (day_end - start_time) / 1.hour
        end
        weekday_hours += hours
      # For the last day (end day)
      elsif current_date == end_time.to_date
        day_start = current_date.beginning_of_day
        hours = (end_time - day_start) / 1.hour
        weekday_hours += hours
      # For any day in between
      else
        weekday_hours += 24.0
      end

      current_date += 1.day
    end

    weekday_hours.round(2)
  end

  module ClassMethods
    # Keep this for backward compatibility
    def weekday_hours_between(start_time, end_time)
      WeekdayHours.weekday_hours_between(start_time, end_time)
    end
  end
end
