# frozen_string_literal: true

module Report
  # Provides rendering ability for CSV-type reports.
  class CSV < BaseTable
    def default_encoding
      "UTF-8"
    end

    def mime_type
      "text/csv"
    end

    def extension
      "csv"
    end

    def header
      { header: :present }
    end

    def self.separator
      ","
    end

    delegate :separator, to: :class

    def render
      ::CSV.generate(col_sep: separator) do |csv|
        csv << labels
        formatted_rows.each { |row| csv << row }
      end.force_encoding("UTF-8")
    end
  end
end
