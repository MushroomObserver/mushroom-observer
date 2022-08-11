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

    errors.add(
      :when, when_message(when_date, " #{:validate_today.t} #{Time.zone.today}")
    )
    errors.add(:when, :validate_future_time.t)
    false
  end

  def check_time(when_date, errors)
    return true unless when_date.is_a?(Time) && when_date > 1.day.from_now

    # As of July 5, 2020 these statements appear to be unreachable
    # because 'when' is a 'date' in the database.
    errors.add(:when, when_message(when_date, "Time.now=#{6.hours.from_now}"))
    errors.add(:when, :validate_future_time.t)
    false
  end

  def check_year(when_date, errors)
    return true unless !when_date.respond_to?(:year) || when_date.year < 1500 ||
                       when_date.year > (1.day.from_now).year

    errors.add(:when, when_message(when_date))
    errors.add(:when, :validate_invalid_year.t)
    false
  end

  def when_message(when_date, details = nil)
    start = "#{:validate_user_selection.t}: #{when_date}"
    return start unless details

    "#{start} #{details}"
  end
end
