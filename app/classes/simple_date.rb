# frozen_string_literal: true

# A day/month/year triple matching form-exif_controller.js's
# `SimpleDate` object -- the shape the JS expects wherever a date is
# passed through a `data-exif-date`-style attribute for `JSON.parse`.
# Keeping this as a distinct type (instead of a formatted display
# string that has to be parsed back apart) lets a Literal prop
# validate it and keeps the display and JSON representations both
# derived from the same value.
class SimpleDate
  attr_reader :day, :month, :year

  def self.from_date(date)
    return nil unless date

    new(day: date.day, month: date.month, year: date.year)
  end

  def initialize(day:, month:, year:)
    @day = day
    @month = month
    @year = year
  end

  def as_json(*)
    { day: day, month: month, year: year }
  end

  def to_json(*)
    as_json.to_json(*)
  end

  # Matches the app's existing "%d-%B-%Y" display convention.
  def to_display
    Date.new(year, month, day).strftime("%d-%B-%Y")
  end
end
