# frozen_string_literal: true

# limitations on Projects
class ProjectConstraints
  attr_reader :params

  def initialize(params)
    @params = params
  end

  def ends_before_start?
    return false if allow_any_dates?

    start_date = parse_date(:start_date)
    end_date = parse_date(:end_date)

    start_date.present? && end_date.present? && (end_date < start_date)
  end

  def allow_any_dates?
    params[:project][:dates_any] == "true" ||
      params[:project]["start_date(1i)"].blank? &&
        params[:project]["end_date(1i)"].blank?
  end

  ##########

  private

  def parse_date(date_key)
    year = params[:project]["#{date_key}(1i)"].to_i
    month = params[:project]["#{date_key}(2i)"].to_i
    day = params[:project]["#{date_key}(3i)"].to_i
    Date.new(year, month, day)
  end
end
