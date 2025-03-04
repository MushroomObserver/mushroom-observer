# frozen_string_literal: true

class API2
  # Upload was supposed to be a URL, but couldn't get download it.
  class CouldntDownloadURL < FatalError
    def initialize(url, error)
      super()
      args.merge!(url: url.to_s, error: "#{error.class.name}: #{error}")
    end
  end
end
