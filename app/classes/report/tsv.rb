# frozen_string_literal: true

module Report
  # Provides rendering ability for TSV-type reports.
  class TSV < BaseTable
    def default_encoding
      "UTF-8"
    end

    def mime_type
      "text/tsv"
    end

    def extension
      "tsv"
    end

    def header
      { header: :present }
    end

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
