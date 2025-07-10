# frozen_string_literal: true

class Inat
  # Obtain an iNat API token --
  # Fetch OAuth and API tokens starting from an authorization code.
  class APIToken
    def initialize(app_id:, site:, redirect_uri:, secret:)
      @app_id = app_id
      @site = site
      @redirect_uri = redirect_uri
      @secret = secret
    end

    def use_auth_code_to_obtain_oauth_access_token(auth_code)
      payload = {
        client_id: @app_id,
        client_secret: @secret,
        code: auth_code,
        redirect_uri: @redirect_uri,
        grant_type: "authorization_code"
      }
      response = RestClient.post("#{@site}/oauth/token", payload)
      JSON.parse(response.body)["access_token"]
    end

    def trade_access_token_for_jwt_api_token(access_token)
      response = RestClient::Request.execute(
        method: :get,
        url: "#{@site}/users/api_token",
        headers: { authorization: "Bearer #{access_token}", accept: :json }
      )
      JSON.parse(response.body)["api_token"]
    end
  end
end
