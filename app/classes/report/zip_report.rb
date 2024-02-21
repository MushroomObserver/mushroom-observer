# frozen_string_literal: true

require("zip")

module Report
  # Provides rendering ability for ZIP-type reports.
  class ZipReport < Base
    attr_accessor :content # List of (name, stream) pairs

    def default_encoding
      "UTF-8"
    end

    def mime_type
      "text/zip"
    end

    def extension
      "zip"
    end

    def header
      { header: :present }
    end

    def initialize(args)
      super(args)
      self.content = []
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
