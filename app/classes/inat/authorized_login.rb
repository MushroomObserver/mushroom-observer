# frozen_string_literal: true

class Inat
  # The login of the iNat user who just authorized MO, from the OAuth
  # authorization code iNat sent back. Proves the MO user controls that
  # iNat account.
  module AuthorizedLogin
    include Inat::Constants

    def self.call(auth_code)
      token = Inat::APIToken.new(
        app_id: APP_ID, site: SITE, redirect_uri: REDIRECT_URI,
        secret: APP_SECRET
      ).obtain_api_token(auth_code)
      response = Inat::APIRequest.new(token).request(path: "users/me")
      JSON.parse(response.body)["results"].first["login"]
    end
  end
end
