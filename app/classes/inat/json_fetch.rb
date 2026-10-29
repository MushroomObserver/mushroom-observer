# frozen_string_literal: true

class Inat
  # Parsed JSON from an iNat API path, or nil when iNat cannot answer.
  # A lookup or a count that fails is an answer of "unknown", not an
  # error page for the admin who happened to open a page, so callers
  # say what they want shown instead.
  module JsonFetch
    private

    def fetch_json(path)
      JSON.parse(Inat::APIRequest.new(nil).request(path: path).body)
    rescue RestClient::Exception, JSON::ParserError, SocketError,
           Errno::ECONNREFUSED => e
      Rails.logger.warn("iNat request failed (#{path}): #{e.message}")
      nil
    end

    def escape(value)
      ERB::Util.url_encode(value.to_s)
    end
  end
end
