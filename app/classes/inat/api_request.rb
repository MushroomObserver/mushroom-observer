# frozen_string_literal: true

# encapsulates requests to the iNat API
# intended for all those requests that are not specific to a single iNatImport
class Inat::APIRequest
  include Inat::InatConstants

  def initialize(token)
    @token = token
  end

  def request(path:, method: :get, payload: {}, headers: {})
    headers = {
      authorization: "Bearer #{@token}",
      content_type: :json,
      accept: :json
    }.merge(headers)

    RestClient::Request.execute(
      method: method,
      url: "#{API_BASE}/#{path}",
      payload: payload.to_json,
      headers: headers
    )
  end
end
