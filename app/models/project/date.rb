# frozen_string_literal: true

module Project::Date
  def current?
    !future? && !past?
  end

  # convenience methods for date range display
  def date_range(format = "%Y-%m-%d")
    "#{start_date_str(format)} - #{end_date_str(format)}"
  end

  def start_date_str(format = "%Y-%m-%d")
    start_date.nil? ? :INDEFINITE.t : start_date.strftime(format)
  end

  def end_date_str(format = "%Y-%m-%d")
    end_date.nil? ? :INDEFINITE.t : end_date.strftime(format)
  end

  ####################################################################

  private

  def future?
    start_date&.future?
  end

  def past?
    end_date&.past?
  end
end
