# frozen_string_literal: true

class API2
  # Upload was supposed to be a local file, but it doesn't exist.
  class FileMissing < FatalError
    def initialize(file)
      super()
      args.merge(file: file.to_s)
    end
  end
end
