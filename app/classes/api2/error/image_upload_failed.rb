# frozen_string_literal: true

class API2
  # Upload didn't make it.
  class ImageUploadFailed < Error
    def initialize(img)
      super()
      args.merge!(error: img.dump_errors)
    end
  end
end
