# Usage example:
# puts DurationFormatter.format_hours(284.65)
# Output: "11 days, 20 hours, 39 minutes"
module DurationFormatter
  def self.format_hours(hours)
    return 'N/A' if hours.nil?

    total_hours = hours.to_f
    days, remaining_hours = total_hours.divmod(24)
    hours, remaining_minutes = remaining_hours.divmod(1)
    minutes = (remaining_minutes * 60).round

    parts = []
    parts << "#{days.to_i} day#{'s' if days != 1}" if days > 0
    parts << "#{hours.to_i} hour#{'s' if hours != 1}" if hours > 0
    parts << "#{minutes} minute#{'s' if minutes != 1}" if minutes > 0 || (days == 0 && hours == 0)

    parts.join(', ')
  end
end
