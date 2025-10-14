# frozen_string_literal: true

module InatImportJobTestDoubles
  include Inat::Constants

  def stub_inat_interactions(
    id_above: 0,
    login: @inat_import.inat_username
  )
    stub_token_requests
    stub_check_username_match(login)
    stub_inat_observation_request(id_above: id_above)
    stub_inat_photo_requests
    stub_modify_inat_observations
  end

  def stub_token_requests
    stub_oauth_token_request
    stub_jwt_request
  end

  def stub_oauth_token_request(oauth_return: {
    status: 200,
    body: { access_token: "MockAccessToken" }.to_json,
    headers: {}
  })
    stub_request(:post, "#{SITE}/oauth/token").
      with(
        body: { "client_id" => Rails.application.credentials.inat.id,
                "client_secret" => Rails.application.credentials.inat.secret,
                "code" => "MockCode",
                "grant_type" => "authorization_code",
                "redirect_uri" => REDIRECT_URI }
      ).
      to_return(oauth_return)
  end

  def stub_jwt_request(jwt_return:
    { status: 200,
      body: { api_token: "MockJWT" }.to_json,
      headers: {} })
    stub_request(:get, "#{SITE}/users/api_token").
      with(
        headers: {
          "Accept" => "application/json",
          "Accept-Encoding" => "gzip;q=1.0,deflate;q=0.6,identity;q=0.3",
          "Authorization" => "Bearer MockAccessToken",
          "Host" => "www.inaturalist.org"
        }
      ).
      to_return(jwt_return)
  end

  def stub_check_username_match(login)
    stub_request(:get, "#{API_BASE}/users/me").
      with(
        headers: {
          "Accept" => "application/json",
          "Accept-Encoding" => "gzip;q=1.0,deflate;q=0.6,identity;q=0.3",
          "Authorization" => "Bearer MockJWT",
          "Content-Type" => "application/json",
          "Host" => "api.inaturalist.org"
        }
      ).
      to_return(status: 200,
                body: "{\"results\":[{\"login\":\"#{login}\"}]}",
                headers: {})
  end

  def stub_inat_observation_request(id_above: 0)
    query_args = {
      iconic_taxa: ICONIC_TAXA,
      id: @inat_import.inat_ids,
      id_above: id_above,
      per_page: 200,
      only_id: false,
      order: "asc",
      order_by: "id",
      verifiable: "any",
      without_field: "Mushroom Observer URL",
      user_id: @inat_import.inat_username
    }

    stub_request(:get, "#{API_BASE}/observations?#{query_args.to_query}").
      with(headers:
    { "Accept" => "application/json",
      "Accept-Encoding" => "gzip;q=1.0,deflate;q=0.6,identity;q=0.3",
      "Authorization" => "Bearer MockJWT",
      "Host" => "api.inaturalist.org" }).
      to_return(body: @mock_inat_response)
  end

  def stub_inat_photo_requests
    JSON.parse(@mock_inat_response)["results"].each do |result|
      result["observation_photos"].each do |photo|
        url = photo["photo"]["url"].sub("square", "original")
        stub_request(
          :get,
          url
        ).
          with(
            headers: {
              "Accept" => "image/*",
              "Accept-Encoding" => "gzip;q=1.0,deflate;q=0.6,identity;q=0.3",
              "Host" => URI(url).host,
              "User-Agent" => "Ruby"
            }
          ).
          to_return(status: 200, body: image_for_stubs, headers: {})
      end
    end
  end

  def image_for_stubs
    @image_for_stubs ||= Rails.root.join("test/images/test_image.jpg").read
  end

  def stub_modify_inat_observations
    stub_add_observation_fields
  end

  def stub_add_observation_fields
    stub_request(:post, "#{API_BASE}/observation_field_values").
      to_return(status: 200, body: "".to_json,
                headers: { "Content-Type" => "application/json" })
  end
end
