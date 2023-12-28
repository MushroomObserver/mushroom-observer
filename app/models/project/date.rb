# frozen_string_literal: true

module Project::Date
  def current?
    !future? && !past?
  end

  # convenience method for date range display
  def date_range(format = "%Y-%m-%d")
    return :form_projects_any.l unless start_date.present? && end_date.present?

    "#{start_date.strftime(format)} - #{end_date.strftime(format)}"
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
