# frozen_string_literal: true

# encapsulates requests to the iNat API
class Inat::APIRequest
  include Inat::Constants

  def initialize(token)
    @token = token
  end

  # timeout: seconds, for a caller that a slow iNat must not hold up.
  # Left out otherwise: RestClient reads `timeout: nil` as no timeout.
  def request(path:, method: :get, payload: {}, headers: {}, timeout: nil)
    default_headers = { content_type: :json, accept: :json }
    default_headers[:authorization] = "Bearer #{@token}" if @token.present?
    options = { method: method, url: "#{API_BASE}/#{path}",
                payload: payload.to_json,
                headers: default_headers.merge(headers) }
    options[:timeout] = timeout if timeout

    count_request
    RestClient::Request.execute(**options)
  end

  private

  # Every iNat API call goes through here (see .claude/rules/
  # inat_import.md), which makes this the one place that can count them
  # against iNat's published ~10,000/day -- see ExternalSiteUsage.
  # Counted before the call, so a request that errors still counts: it
  # reached iNat either way. Accounting failures are swallowed rather
  # than allowed to break an import.
  def count_request
    ExternalSiteUsage.record_request(ExternalSite.inaturalist)
  rescue StandardError => e
    Rails.logger.warn("iNat usage accounting failed: #{e.message}")
  end
end
