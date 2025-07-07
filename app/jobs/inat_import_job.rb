# frozen_string_literal: true

class InatImportJob < ApplicationJob
  # iNat's id for the MO application
  # Different in production vs. test & development
  APP_ID = InatImportsController::APP_ID
  # site for authorization, authentication
  SITE = InatImportsController::SITE
  # iNat calls this after iNat user authorizes MO access to user's data
  REDIRECT_URI = InatImportsController::REDIRECT_URI
  # The iNat API
  API_BASE = InatImportsController::API_BASE
  # limit results iNat API requests, with Protozoa as a proxy for slime molds
  ICONIC_TAXA = "Fungi,Protozoa"
  # This string + date is added to description of iNat observation
  IMPORTED_BY_MO = "Imported by Mushroom Observer"

  queue_as :default

  def perform(inat_import)
    create_ivars(inat_import)
    access_token =
      use_auth_code_to_obtain_oauth_access_token(@inat_import.token)
    api_token = trade_access_token_for_jwt_api_token(access_token)
    ensure_importing_own_observations(api_token)
    @inat_import.update(token: api_token, state: "Importing")
    import_requested_observations
  rescue StandardError => e
    log("Error occurred: #{e.message}")
    @inat_import.add_response_error(e)
  ensure
    done
  end

  private

  def create_ivars(inat_import)
    @inat_import = inat_import
    log(
      "InatImportJob #{inat_import.id} started, user: #{inat_import.user_id}"
    )
    @user = @inat_import.user
  end

  # https://www.inaturalist.org/pages/api+reference#authorization_code_flow
  def use_auth_code_to_obtain_oauth_access_token(auth_code)
    log("Obtaining OAuth access token")
    payload = { client_id: APP_ID,
                client_secret: Rails.application.credentials.inat.secret,
                code: auth_code,
                redirect_uri: REDIRECT_URI,
                grant_type: "authorization_code" }

    begin
      oauth_response = RestClient.post("#{SITE}/oauth/token", payload)
    rescue RestClient::Unauthorized, RestClient::ExceptionWithResponse => e
      raise("OAuth token request failed: #{e.message}")
    end

    token = JSON.parse(oauth_response.body)["access_token"]
    @inat_import.update(token: token)
    log("Obtained OAuth access token: #{masked_token(token)}")
    token
  end

  def done
    log("Updating inat_import state to Done")
    update_inat_import
    update_user_inat_username
  end

  def update_inat_import
    @inat_import.update(state: "Done", ended_at: Time.zone.now)
  end

  # https://www.inaturalist.org/pages/api+recommended+practices
  def trade_access_token_for_jwt_api_token(access_token)
    log("Obtaining jwt")
    begin
      jwt_response = RestClient::Request.execute(
        method: :get, url: "#{SITE}/users/api_token",
        headers: { authorization: "Bearer #{access_token}", accept: :json }
      )
    rescue RestClient::Unauthorized, RestClient::ExceptionWithResponse => e
      raise("JWT request failed: #{e.message}")
    end
    api_token = JSON.parse(jwt_response)["api_token"]
    log("Obtained JWT API token: #{masked_token(api_token)}")
    api_token
  end

  # Ensure that normal MO users import only their own iNat observations.
  # iNat allows MO user A to import iNat obs of iNat user B
  # if B authorized MO to access B's iNat data.  We don't want that.
  # Therefore check that the iNat login provided in the import form
  # is that of the user currently logged-in to iNat.
  def ensure_importing_own_observations(api_token)
    return log("Skipped own-obs check (SuperImporter)") if super_importer?

    headers = { authorization: "Bearer #{api_token}",
                content_type: :json, accept: :json }
    begin
      # fetch the logged-in iNat user
      # https://api.inaturalist.org/v1/docs/#!/Users/get_users_me
      response = RestClient.get("#{API_BASE}/users/me", headers)
      @inat_logged_in_user = JSON.parse(response.body)["results"].first["login"]
      log("inat_logged_in_user: #{@inat_logged_in_user}")
    rescue RestClient::Unauthorized, RestClient::ExceptionWithResponse => e
      raise("iNat API user request failed: #{e.message}")
    end

    raise(:inat_wrong_user.t) unless right_user?(@inat_logged_in_user)
  end

  def super_importer?
    InatImport.super_importers.include?(@user)
  end

  def right_user?(inat_logged_in_user)
    inat_logged_in_user == @inat_import.inat_username
  end

  def import_requested_observations
    inat_ids = inat_id_list
    return log("No observations requested") if @inat_import[:import_all].
                                               blank? && inat_ids.blank?

    # Search for one page of results at a time, until done with all pages
    # To get one page, use iNats `per_page` & `id_above` params.
    # https://api.inaturalist.org/v1/docs/#!/Observations/get_observations
    parser = Inat::PageParser.new(@inat_import, inat_ids, restricted_user_login)
    while parsing?(parser); end
  end

  def inat_id_list
    @inat_import.inat_ids.delete(" ")
  end

  def parsing?(parser)
    # get a page of observations with id > id of last imported obs
    parsed_page = parser.next_page
    return false if parsed_page.nil?

    @inat_import.update(importables: parsed_page["total_results"])
    return false if page_empty?(parsed_page)

    import_page(parsed_page)

    parser.last_import_id = parsed_page["results"].last["id"]
    return true unless last_page?(parsed_page)

    log("Imported requested observations")
    false
  end

  def page_empty?(page)
    page["total_results"].zero?
  end

  def last_page?(parsed_page)
    parsed_page["total_results"] <=
      parsed_page["page"] * parsed_page["per_page"]
  end

  # limit iNat API search to observations by iNat user with this login
  def restricted_user_login
    if super_importer?
      nil
    else
      @inat_import.inat_username
    end
  end

  def import_page(page)
    page["results"].each do |result|
      import_one_result(JSON.generate(result))
    end
  end

  def import_one_result(result)
    @inat_obs = Inat::Obs.new(result)
    return unless @inat_obs.importable?

    builder = Inat::MoObservationBuilder.new(inat_obs: @inat_obs, user: @user)
    @observation = builder.mo_observation

    # NOTE: update field slip 2024-09-09 jdc
    # https://github.com/MushroomObserver/mushroom-observer/issues/2380
    update_inat_observation
    increment_imported_counts
    update_timings
  end

  def update_inat_observation
    update_mushroom_observer_url_field
    sleep(1)
    update_description
  end

  def update_mushroom_observer_url_field
    update_inat_observation_field(observation_id: @inat_obs[:id],
                                  field_id: 5005,
                                  value: "#{MO.http_domain}/#{@observation.id}")
  end

  def update_inat_observation_field(observation_id:, field_id:, value:)
    payload = { observation_field_value: { observation_id: observation_id,
                                           observation_field_id: field_id,
                                           value: value } }
    headers = { authorization: "Bearer #{@inat_import.token}",
                content_type: :json, accept: :json }
    RestClient.post("#{API_BASE}/observation_field_values",
                    payload.to_json, headers)
  end

  def update_description
    return if super_importer? && importing_someone_elses_obs?

    description = @inat_obs[:description]
    updated_description =
      "#{IMPORTED_BY_MO} #{Time.zone.today.strftime(MO.web_date_format)}"
    updated_description.prepend("#{description}\n\n") if description.present?

    payload = { observation: { description: updated_description,
                               ignore_photos: 1 } }
    headers = { authorization: "Bearer #{@inat_import.token}",
                content_type: :json, accept: :json }
    # iNat API uses PUT + ignore_photos, not PATCH, to update an observation
    # https://api.inaturalist.org/v1/docs/#!/Observations/put_observations_id
    RestClient.put("#{API_BASE}/observations/#{@inat_obs[:id]}?ignore_photos=1",
                   payload.to_json, headers)
  end

  def importing_someone_elses_obs?
    @inat_obs[:user][:login] != @inat_import.inat_username
  end

  def increment_imported_counts
    @inat_import.increment!(:imported_count) # count in this job
    @inat_import.increment!(:total_imported_count) # all-time count
  end

  def update_timings
    total_seconds =
      @inat_import.total_seconds.to_i + @inat_import.last_obs_elapsed_time
    @inat_import.update(
      total_seconds: total_seconds,
      avg_import_time: total_seconds / (@inat_import.imported_count || 1)
    )
    @inat_import.reset_last_obs_start
  end

  def update_user_inat_username
    # Prevent MO users from setting their inat_username
    # to a non-existent iNat login
    return unless job_successful_enough?

    @inat_import.user.update(inat_username: @inat_import.inat_username)
    log("Updated user inat_username")
  end

  # job successful enough to justify updating the MO user's iNat user_name
  def job_successful_enough?
    @inat_import.response_errors.empty? ||
      @inat_import.imported_count&.positive?
  end

  def masked_token(str)
    # Return the string as is if its length is less than or equal to 6
    return str if str.length <= 6

    # Extract the first 3 and last 3 characters
    first_part = str[0, 3]
    last_part = str[-3, 3]

    # Calculate the number of asterisks needed
    asterisks = "*" * (str.length - 6)

    # Combine the parts
    "#{first_part}#{asterisks}#{last_part}"
  end
end
