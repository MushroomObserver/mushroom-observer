# frozen_string_literal: true

module Report
  # Provides rendering ability for TSV-type reports.
  class TSV < Report::BaseTable
    self.default_encoding = "UTF-8"
    self.mime_type = "text/tsv"
    self.extension = "tsv"
    self.header = { header: :present }

    def render
      [
        labels.join("\t"),
        formatted_rows.map do |row|
          row.map { |v| v.to_s.gsub(/\s+/, " ") }.join("\t")
        end
      ].join("\n").force_encoding("UTF-8")
    end
  end
end
