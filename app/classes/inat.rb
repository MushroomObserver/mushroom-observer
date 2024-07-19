# frozen_string_literal: true

# The value returned by calling the iNat API
# This class should eventually handle **all** iNat API requests
# in order to rate limit per iNat policy
# (60 requests/minute, <10K requests/day)
# https://api.inaturalist.org/v1/docs/
class Inat
  API_BASE = "https://api.inaturalist.org/v1"

  # TODO: Add a verb param so that this can be used for non-GET requests
  def initialize(operation:, token: "")
    sleep(1.second) # 60 requests/minute rate limit per iNat policy
    # https://www.inaturalist.org/pages/api+reference#authorization_code_flow
    headers = { "Authorization" => "Bearer #{token}" }
    @inat = RestClient.get("#{API_BASE}#{operation}", headers)
  end

  def body
    @inat.body
  end
end
