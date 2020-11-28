# frozen_string_literal: true

module ObservationReport
  # Provides rendering ability for CSV-type reports.
  class CSV < ObservationReport::Base
    require "csv"

    self.default_encoding = "UTF-8"
    self.mime_type = "text/csv"
    self.extension = "csv"
    self.header = { header: :present }
    self.separator = ","

    def render
      ::CSV.generate(col_sep: separator) do |csv|
        csv << labels
        formatted_rows.each { |row| csv << row }
      end.force_encoding("UTF-8")
    end
  end
end
