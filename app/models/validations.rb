# frozen_string_literal: true

# validations used by multiple objects
module Validations
  # Validates obj.when.
  # used by: Observation, SpeciesList
  def validate_when(when_date, errors)
    check_date(when_date, errors) &&
      check_time(when_date, errors) &&
      check_year(when_date, errors)
  end

  ##############################################################################

  private

  def check_date(when_date, errors)
    return true unless when_date.is_a?(Date) && when_date > Time.zone.tomorrow

    errors.add(:when,
               when_message(when_date, "Time.zone.today=#{Time.zone.today}"))
    errors.add(:when, :validate_future_time.t)
    false
  end

  def check_time(when_date, errors)
    unless when_date.is_a?(Time) && when_date > Time.zone.now + 1.day
      return true
    end

    # As of July 5, 2020 these statements appear to be unreachable
    # because 'when' is a 'date' in the database.
    errors.add(:when,
               when_message(when_date, "Time.now=#{Time.zone.now + 6.hours}"))
    errors.add(:when, :validate_future_time.t)
    false
  end

  def check_year(when_date, errors)
    return true unless !when_date.respond_to?(:year) || when_date.year < 1500 ||
                       when_date.year > (Time.zone.now + 1.day).year

    errors.add(:when, when_message(when_date))
    errors.add(:when, :validate_invalid_year.t)
    false
  end

  def when_message(when_date, details = nil)
    start = "#{when_date.class.name}:#{when_date}"
    return start unless details

    "#{start} #{details}"
  end
end
