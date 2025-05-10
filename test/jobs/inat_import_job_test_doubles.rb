# frozen_string_literal: true

module InatImportJobTestDoubles
  # url for iNat authorization and authentication requests
  SITE = InatImportsController::SITE
  # MO url called by iNat after iNat user authorizes MO to access their data
  REDIRECT_URI = InatImportsController::REDIRECT_URI
  # iNat API url
  API_BASE = InatImportsController::API_BASE
  # Value of the iNat API "iconic_taxa" query param
  ICONIC_TAXA = InatImportJob::ICONIC_TAXA
  # base url for iNat CC-licensed and public domain photos
  LICENSED_PHOTO_BASE = "https://inaturalist-open-data.s3.amazonaws.com/photos"
  # base url for iNat unlicensed photos
  UNLICENSED_PHOTO_BASE = "https://static.inaturalist.org/photos"

  def stub_inat_interactions(
    inat_import:, mock_inat_response:, id_above: 0,
    login: inat_import.inat_username, superimporter: false
  )
    stub_token_requests
    stub_check_username_match(login)
    stub_inat_observation_request(inat_import: inat_import,
                                  mock_inat_response: mock_inat_response,
                                  id_above: id_above,
                                  superimporter: superimporter)
    stub_inat_photo_requests(mock_inat_response)
    stub_modify_inat_observations(mock_inat_response)
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
    add_stub(stub_request(:post, "#{SITE}/oauth/token").
      with(
        body: { "client_id" => Rails.application.credentials.inat.id,
                "client_secret" => Rails.application.credentials.inat.secret,
                "code" => "MockCode",
                "grant_type" => "authorization_code",
                "redirect_uri" => REDIRECT_URI }
      ).
      to_return(oauth_return))
  end

  def stub_jwt_request(jwt_return:
    { status: 200,
      body: { api_token: "MockJWT" }.to_json,
      headers: {} })
    add_stub(stub_request(:get, "#{SITE}/users/api_token").
      with(
        headers: {
          "Accept" => "application/json",
          "Accept-Encoding" => "gzip;q=1.0,deflate;q=0.6,identity;q=0.3",
          "Authorization" => "Bearer MockAccessToken",
          "Host" => "www.inaturalist.org"
        }
      ).
      to_return(jwt_return))
  end

  def stub_check_username_match(login)
    add_stub(stub_request(:get, "#{API_BASE}/users/me").
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
                headers: {}))
  end

  def stub_inat_observation_request(inat_import:,
                                    mock_inat_response:, id_above: 0,
                                    superimporter: false)
    query_args = {
      iconic_taxa: ICONIC_TAXA,
      id: inat_import.inat_ids,
      id_above: id_above,
      per_page: 200,
      only_id: false,
      order: "asc",
      order_by: "id",
      without_field: "Mushroom Observer URL",
      user_login: (inat_import.inat_username unless superimporter)
    }

    add_stub(stub_request(:get,
                          "#{API_BASE}/observations?#{query_args.to_query}").
      with(headers:
    { "Accept" => "application/json",
      "Accept-Encoding" => "gzip;q=1.0,deflate;q=0.6,identity;q=0.3",
      "Authorization" => "Bearer MockJWT",
      "Host" => "api.inaturalist.org" }).
      to_return(body: mock_inat_response))
  end

  def stub_inat_photo_requests(mock_inat_response)
    JSON.parse(mock_inat_response)["results"].each do |result|
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

  def stub_modify_inat_observations(mock_inat_response)
    stub_add_observation_fields
    stub_update_descriptions(mock_inat_response)
  end

  def stub_add_observation_fields
    add_stub(stub_request(:post, "#{API_BASE}/observation_field_values").
      to_return(status: 200, body: "".to_json,
                headers: { "Content-Type" => "application/json" }))
  end

  def stub_update_descriptions(mock_inat_response)
    date = Time.zone.today.strftime(MO.web_date_format)
    observations = JSON.parse(mock_inat_response)["results"]
    observations.each do |obs|
      updated_description =
        "Imported by Mushroom Observer #{date}"
      if obs["description"].present?
        updated_description.prepend("#{obs["description"]}\n\n")
      end

      body = {
        observation: {
          description: updated_description,
          ignore_photos: 1
        }
      }
      headers = { authorization: "Bearer MockJWT",
                  content_type: "application/json", accept: "application/json" }
      add_stub(
        stub_request(
          :put, "#{API_BASE}/observations/#{obs["id"]}?ignore_photos=1"
        ).
        with(body: body.to_json, headers: headers).
        to_return(status: 200, body: "".to_json, headers: {})
      )
    end
  end
end