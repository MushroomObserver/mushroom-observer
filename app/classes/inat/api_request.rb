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

    RestClient::Request.execute(
      method: method,
      url: "#{API_BASE}/#{path}",
      payload: payload.to_json,
      headers: headers
    )
  end
end
