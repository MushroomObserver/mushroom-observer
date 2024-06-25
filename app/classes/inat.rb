# frozen_string_literal: true

# Class to handle **all** requests to iNat API
# in order to rate limit per iNat policy
# 60 requests/minute, <10K requests/day
# https://api.inaturalist.org/v1/docs/
class Inat
  API_BASE = "https://api.inaturalist.org/v1"

  def initialize(operation)
    sleep(1.second) # 60 requests/minute rate limit per iNat policy

    @inat = HTTParty.get("#{API_BASE}#{operation}")
  end

  def body
    @inat.body
  end
end
