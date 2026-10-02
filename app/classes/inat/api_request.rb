# frozen_string_literal: true

# encapsulates requests to the iNat API
class Inat::APIRequest
  include Inat::Constants

  def initialize(token)
    @token = token
  end

  def request(path:, method: :get, payload: {}, headers: {})
    default_headers = { content_type: :json, accept: :json }
    default_headers[:authorization] = "Bearer #{@token}" if @token.present?
    headers = default_headers.merge(headers)

    count_request
    RestClient::Request.execute(
      method: method,
      url: "#{API_BASE}/#{path}",
      payload: payload.to_json,
      headers: headers
    )
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
