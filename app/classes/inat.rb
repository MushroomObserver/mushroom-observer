# frozen_string_literal: true

# The value returned by calling the iNat API
# This class should eventually handle **all** iNat API requests
# in order to rate limit per iNat policy
# (60 requests/minute, <10K requests/day)
# https://api.inaturalist.org/v1/docs/
class Inat
  API_BASE = "https://api.inaturalist.org/v1"

  def initialize(operation:, token: "")
    # This should eventually be replaced by class-wide limit
    # https://github.com/MushroomObserver/mushroom-observer/issues/2320
    sleep(1.second)
    headers = { "Authorization" => "Bearer #{token}" }
    @inat = RestClient.get("#{API_BASE}#{operation}", headers)
  end

  delegate :body, to: :@inat
end
