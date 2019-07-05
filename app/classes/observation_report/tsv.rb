module ObservationReport
  # Provides rendering ability for TSV-type reports.
  class TSV < ObservationReport::Base
    self.default_encoding = "UTF-8"
    self.mime_type = "text/tsv"
    self.extension = "tsv"
    self.header = { header: :present }

    def render
      [
        labels.join("\t"),
        formatted_rows.map { |row| row.join("\t") }
      ].join("\n").force_encoding("UTF-8")
    end
  end
end
