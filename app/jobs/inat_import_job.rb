# frozen_string_literal: true

class InatImportJob < ApplicationJob
  include Inat::Constants

  queue_as :default

  delegate :token, to: :@inat_import

  def perform(inat_import)
    create_ivars(inat_import)
    # use_auth_code_to_obtain_oauth_access_token
    # trade_access_token_for_jwt_api_token
    obtain_api_token
    ensure_importing_own_observations
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

  def obtain_api_token
    token_service = Inat::APIToken.new(
      app_id: APP_ID, site: SITE,
      redirect_uri: REDIRECT_URI,
      secret: Rails.application.credentials.inat.secret
    )
    # https://www.inaturalist.org/pages/api+reference#authorization_code_flow
    access_token =
      token_service.
      use_auth_code_to_obtain_oauth_access_token(@inat_import.token)
    # https://www.inaturalist.org/pages/api+recommended+practices
    api_token =
      token_service.
      trade_access_token_for_jwt_api_token(access_token)
    @inat_import.update(token: api_token)
  end

  # Ensure that normal MO users import only their own iNat observations.
  # iNat allows MO user A to import iNat obs of iNat user B
  # if B authorized MO to access B's iNat data.  We don't want that.
  # Therefore check that the iNat login provided in the import form
  # is that of the user currently logged-in to iNat.
  def ensure_importing_own_observations
    return log("Skipped own-obs check (SuperImporter)") if super_importer?

    begin
      response = Inat::APIRequest.new(token).request(path: "users/me")
    rescue RestClient::Unauthorized, RestClient::ExceptionWithResponse => e
      raise("iNat API user request failed: #{e.message}")
    end

    @inat_logged_in_user = JSON.parse(response.body)["results"].first["login"]
    log("inat_logged_in_user: #{@inat_logged_in_user}")
    raise(:inat_wrong_user.t) unless right_user?(@inat_logged_in_user)
  end

  def super_importer?
    InatImport.super_importers.include?(@user)
  end

  def right_user?(inat_logged_in_user)
    inat_logged_in_user == @inat_import.inat_username
  end

  def import_requested_observations
    @inat_import.update(state: "Importing")
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
    update_inat_observation_field(
      observation_id: @inat_obs[:id],
      field_id: MO_URL_OBSERVATION_FIELD_ID,
      value: "#{MO.http_domain}/#{@observation.id}"
    )
  end

  def update_inat_observation_field(observation_id:, field_id:, value:)
    payload = { observation_field_value: { observation_id: observation_id,
                                           observation_field_id: field_id,
                                           value: value } }
    Inat::APIRequest.new(token).
      request(method: :post, path: "observation_field_values", payload: payload)
  end

  def update_description
    return if super_importer? && importing_someone_elses_obs?

    description = @inat_obs[:description]
    updated_description =
      "#{IMPORTED_BY_MO} #{Time.zone.today.strftime(MO.web_date_format)}"
    updated_description.prepend("#{description}\n\n") if description.present?

    payload = { observation: { description: updated_description,
                               ignore_photos: 1 } }
    # iNat API uses PUT + ignore_photos, not PATCH, to update an observation
    # https://api.inaturalist.org/v1/docs/#!/Observations/put_observations_id
    path = "observations/#{@inat_obs[:id]}?ignore_photos=1"
    Inat::APIRequest.new(token).
      request(method: :put, path: path, payload: payload)
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

  def done
    log("Updating inat_import state to Done")
    @inat_import.update(state: "Done", ended_at: Time.zone.now)
    update_user_inat_username
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
end
