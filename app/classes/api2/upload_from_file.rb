# frozen_string_literal: true

# API2
class API2
  # Class encapsulating an upload from a file stored locally on the server
  class UploadFromFile < Upload
    def initialize(file)
      raise(FileMissing.new(file)) unless File.exist?(file)

      super()
      self.content = File.open(file, "rb")
      self.content_length = File.size(file)
      self.content_type = `file --mime -b #{file}`.sub(/[;\s].*/, "")
    end
  end
end
