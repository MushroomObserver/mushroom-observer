# frozen_string_literal: true

# validations used by multiple objects
module Validations
  extend ActiveSupport::Concern

  # Validates obj.when.
  # Includes setting it to current date if user set it to nil.
  # used by: Observation, SpeciesList
  def validate_when
    self.when ||= Time.zone.now
    check_date && check_time && check_year
  end

  ##############################################################################

  private

  def check_date
    return true unless self.when.is_a?(Date) && self.when > Time.zone.tomorrow

    errors.add(:when, when_message("Time.zone.today=#{Time.zone.today}"))
    errors.add(:when, :validate_future_time.t)
    false
  end

  def when_message(details = nil)
    start = "self.when=#{self.when.class.name}:#{self.when}"
    return start unless details

    "#{start} #{details}"
  end

  def check_time
    unless self.when.is_a?(Time) && self.when > Time.zone.now + 1.day
      return true
    end

    # As of July 5, 2020 these statements appear to be unreachable
    # because 'when' is a 'date' in the database.
    errors.add(:when, when_message("Time.now=#{Time.zone.now + 6.hours}"))
    errors.add(:when, :validate_future_time.t)
    false
  end

  def check_year
    return true unless !self.when.respond_to?(:year) || self.when.year < 1500 ||
                       self.when.year > (Time.zone.now + 1.day).year

    errors.add(:when, when_message)
    errors.add(:when, :validate_invalid_year.t)
    false
  end
end
