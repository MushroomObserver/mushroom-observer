# frozen_string_literal: true

# Main document class for generating PDF labels
class ObservationLabels
  def initialize(user, query)
    @report = if rtf_user?(user)
                ObservationLabels::RtfLabels.new(query)
              else
                ObservationLabels::PdfLabels.new(query)
              end
  end

  # Method compatible with Rails send_data
  delegate :body, to: :@report

  delegate :mime_type, to: :@report

  delegate :http_disposition, to: :@report

  delegate :encoding, to: :@report

  delegate :filename, to: :@report

  def header
    {}
  end

  private

  def rtf_user?(user)
    false
  end
end
