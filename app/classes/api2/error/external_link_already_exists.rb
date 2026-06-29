# frozen_string_literal: true

class API2
  # Tried to create an external_link identical to one that already exists
  # (same observation + site + url). Multiple distinct links per (obs, site)
  # are allowed (#4565); exact duplicates are not.
  class ExternalLinkAlreadyExists < FatalError
    def initialize(url)
      super()
      args.merge!(url: url)
    end
  end
end
