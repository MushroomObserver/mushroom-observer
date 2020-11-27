# frozen_string_literal: true

require("zip")

module ObservationReport
  # Provides rendering ability for ZIP-type reports.
  class ZipReport < ObservationReport::Base
    attr_accessor :content # List of (name, stream) pairs

    self.default_encoding = "UTF-8"
    self.mime_type = "text/zip"
    self.extension = "zip"
    self.header = { header: :present }

    def initialize(args)
      super(args)
      self.content = []
    end

    def filename
      "test.#{extension}"
    end

    def render
      # generate a Zip from a set of steams
      stringio = Zip::OutputStream.write_buffer do |zio|
        content.each do |name, data|
          zio.put_next_entry(name)
          zio.write(data)
        end
      end
      stringio.string.force_encoding("UTF-8")
    end
  end
end
