# frozen_string_literal: true

module ObservationReport
  # Provides rendering ability for ZIP-type reports.
  class Zip < ObservationReport::Base
    self.default_encoding = "UTF-8"
    self.mime_type = "text/zip"
    self.extension = "zip"
    self.header = { header: :present }

    def render
      # generate a Zip from a set of steams
    end
  end
end
