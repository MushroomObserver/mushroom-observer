# frozen_string_literal: true

class API2
  # Refused to overwrite an image's existing (different) dhash. The API
  # only fills missing dhashes -- a mismatch is surfaced, never clobbered
  # (see #4585; hashes are derived data, but an unexpected difference is
  # signal worth keeping).
  class ImageDhashMismatch < FatalError
    def initialize(image, submitted)
      super()
      args.merge!(id: image.id, existing: image.dhash, submitted: submitted)
    end
  end
end
