# frozen_string_literal: true

module Project::Date
  def current?
    !future? && !past?
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
