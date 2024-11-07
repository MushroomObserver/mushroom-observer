# frozen_string_literal: true

class InatImportJob < ApplicationJob
  # iNat's id for the MO application
  APP_ID = Observations::InatImportsController::APP_ID
  # site for authorization, authentication
  SITE = Observations::InatImportsController::SITE
  # iNat calls this after iNat user authorizes MO access to user's data
  REDIRECT_URI = Observations::InatImportsController::REDIRECT_URI
  # The iNat API
  API_BASE = Observations::InatImportsController::API_BASE
  # limit results iNat API requests, with Protozoa as a proxy for slime molds
  ICONIC_TAXA = "Fungi,Protozoa"
  # This string + date is added to description of iNat observation
  IMPORTED_BY_MO = "Imported by Mushroom Observer"

  queue_as :default

  def perform(inat_import)
    @inat_import = inat_import
    @super_importers = InatImport.super_importers
    @user = @inat_import.user
    log("Job started with inat_import ID: #{inat_import.id}")

    begin
      access_token =
        use_auth_code_to_obtain_oauth_access_token(@inat_import.token)
      log("Obtained OAuth access token")
      @inat_import.update(token: access_token)

      api_token = trade_access_token_for_jwt_api_token(@inat_import.token)
      log("Obtained JWT API token")
      ensure_importing_own_observations(api_token)
      log("Checked importing own observations")
      @inat_import.update(token: api_token, state: "Importing")
      import_requested_observations
      log("Imported requested observations")
    rescue StandardError => e
      log("Error occurred: #{e.message}")
      @inat_import.add_response_error(e)
    ensure
      done
      log("Job done")
    end

    done
  end

  private

  # https://www.inaturalist.org/pages/api+reference#authorization_code_flow
  def use_auth_code_to_obtain_oauth_access_token(auth_code)
    log("Obtaining oauth access token")
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

    JSON.parse(oauth_response.body)["access_token"]
  end

  def done
    log("Updating inat_import state to Done")
    @inat_import.update(state: "Done")
    update_user_inat_username
    log("Updated user inat_username")
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
    JSON.parse(jwt_response)["api_token"]
  end

  # Ensure that MO users importing only their own iNat observations.
  # iNat allows MO user A to import iNat obs of iNat user B
  # if B authorized MO to access B's iNat data.  We don't want that.
  # Therefore check that the iNat login provided in the import form
  # is that of the user currently logged-in to iNat.
  def ensure_importing_own_observations(api_token)
    log("Starting own-obs check")
    if super_importer?
      log("Aborting own-obs check (SuperImporter)")
      return
    end

    log("Continuing own-obs check")
    headers = { authorization: "Bearer #{api_token}",
                content_type: :json, accept: :json }
    begin
      # fetch the logged-in iNat user
      # https://api.inaturalist.org/v1/docs/#!/Users/get_users_me
      response = RestClient.get("#{API_BASE}/users/me", headers)
    rescue RestClient::Unauthorized, RestClient::ExceptionWithResponse => e
      raise("iNat API user request failed: #{e.message}")
    end

    raise(:inat_wrong_user.t) unless right_user?(response)

    log("Finished own-obs check")
  end

  def super_importer?
    @super_importers.include?(@user)
  end

  def right_user?(response)
    inat_logged_in_user = JSON.parse(response.body)["results"].first["login"]
    inat_logged_in_user == @inat_import.inat_username
  end

  def import_requested_observations
    @inat_manager = User.find_by(login: "MO Webmaster")
    inat_ids = inat_id_list
    return if @inat_import[:import_all].blank? && inat_ids.blank?

    # Search for one page of results at a time, until done with all pages
    # To get one page, use iNats `per_page` & `id_above` params.
    # https://api.inaturalist.org/v1/docs/#!/Observations/get_observations
    last_import_id = 0
    loop do
      # get a page of observations with id > id of last imported obs
      page_of_observations =
        next_page(id: inat_ids, id_above: last_import_id,
                  user_login: restricted_user_login)

      parsed_page = JSON.parse(page_of_observations)
      @inat_import.update(importables: parsed_page["total_results"])
      break if page_empty?(parsed_page)

      import_page(page_of_observations)

      last_import_id = parsed_page["results"].last["id"]
      next unless last_page?(parsed_page)

      break
    end
  end

  # limit iNat API search to observations by iNat user with this login
  def restricted_user_login
    if super_importer?
      nil
    else
      @inat_import.inat_username
    end
  end

  # Get one page of observations (up to 200)
  # This is where we actually hit the iNat API
  # https://api.inaturalist.org/v1/docs/#!/Observations/get_observations
  # https://stackoverflow.com/a/11251654/3357635
  # NOTE: The `ids` parameter may be a comma-separated list of iNat obs
  # ids - that needs to be URL encoded to a string when passed as an arg here
  # because URI.encode_www_form deals with arrays by passing the same key
  # multiple times.
  def next_page(**args)
    query_args = {
      id: nil, id_above: nil, only_id: false, per_page: 200,
      order: "asc", order_by: "id",
      # obss of only the iNat user with iNat login @inat_import.inat_username
      user_login: nil,
      iconic_taxa: ICONIC_TAXA
    }.merge(args)

    query = URI.encode_www_form(query_args)

    # ::Inat.new(operation: query, token: @inat_import.token).body
    # Nimmo 2024-06-19 jdc. Moving the request from the inat class to here.
    # RestClient::Request.execute wasn't available in the class
    headers = { authorization: "Bearer #{@inat_import.token}", accept: :json }
    @inat = RestClient::Request.execute(
      method: :get, url: "#{API_BASE}/observations?#{query}", headers: headers
    )
    raise(:inat_page_of_obs_failed.t) if failed_to_get_next_page?

    @inat
  end

  def failed_to_get_next_page?
    @inat.is_a?(RestClient::RequestFailed) ||
      @inat.instance_of?(RestClient::Response) && @inat.code != 200 ||
      # RestClient was happy, but the user wasn't authorized
      @inat.is_a?(Hash) && @inat[:status] == 401
  end

  def page_empty?(page)
    page["total_results"].zero?
  end

  def last_page?(parsed_page)
    parsed_page["total_results"] <=
      parsed_page["page"] * parsed_page["per_page"]
  end

  def inat_id_list
    @inat_import.inat_ids.delete(" ")
  end

  def import_page(page)
    JSON.parse(page)["results"].each do |result|
      import_one_result(JSON.generate(result))
    end
  end

  def import_one_result(result)
    @inat_obs = Inat::Obs.new(result)
    return unless @inat_obs.importable?

    create_observation
    add_inat_images(@inat_obs[:observation_photos])
    update_names_and_proposals
    add_inat_sequences
    add_snapshot_of_import_comment
    # NOTE: update field slip 2024-09-09 jdc
    # https://github.com/MushroomObserver/mushroom-observer/issues/2380
    update_inat_observation
    increment_imported_count
  end

  def create_observation
    @observation = Observation.create(new_obs_params)
    # Ensure this Name wins consensus_calc ties
    # by creating this naming and vote first
    add_naming_with_vote(name: @observation.name)
    @observation.log(:log_observation_created)
  end

  def new_obs_params
    name_id = adjust_for_provisional
    { user: @user,
      when: @inat_obs.when,
      location: @inat_obs.location,
      where: @inat_obs.where,
      lat: @inat_obs.lat,
      lng: @inat_obs.lng,
      gps_hidden: @inat_obs.gps_hidden,
      name_id: name_id,
      specimen: @inat_obs.specimen?,
      text_name: Name.find(name_id).text_name,
      notes: @inat_obs.notes,
      source: @inat_obs.source,
      inat_id: @inat_obs[:id] }
  end

  # NOTE: 1. iNat users seem to add a prov name only if there's a sequence.
  #  2. iNat cannot use a prov name as the iNat identication.
  # So if iNat has a provisional name observation field, then
  #   add an MO provisional name if none exists, and
  #   treat the provisional name as the MO consensus.
  def adjust_for_provisional
    prov_name = @inat_obs.provisional_name
    return @inat_obs.name_id if prov_name.blank?

    if need_new_prov_name?(prov_name)
      name = add_provisional_name(prov_name)
      name.id
    else
      best_mo_homonym(prov_name).id
    end
  end

  def need_new_prov_name?(prov_name)
    prov_name.blank? || Name.where(text_name: prov_name).none?
  end

  def add_provisional_name(prov_name)
    params = { method: :post, action: :name,
               api_key: inat_manager_key.key,
               name: "#{prov_name} crypt. temp.",
               rank: "Species" }
    api = API2.execute(params)

    new_name = api.results.first
    new_name.log(:log_name_created)
    new_name
  end

  def add_inat_images(inat_obs_photos)
    inat_obs_photos.each do |obs_photo|
      photo = Inat::ObsPhoto.new(obs_photo)
      api = Inat::PhotoImporter.new(photo_importer_params(photo)).api

      # NOTE: Error handling? 2024-06-19 jdc.
      # https://github.com/MushroomObserver/mushroom-observer/issues/2382
      image = Image.find(api.results.first.id)

      # Imaage attributes to potentially update manually
      # t.boolean "ok_for_export", default: true, null: false
      # t.boolean "gps_stripped", default: false, null: false
      # t.boolean "diagnostic", default: true, null: false
      image.update(
        user_id: @user.id, # throws Error if done as API param above
        # NOTE: 2024-09-09 get when from image EXIF instead of @observation.when
        # https://github.com/MushroomObserver/mushroom-observer/issues/2379
        when: @observation.when # throws Error if done as API param above
      )
      @observation.add_image(image)
    end
  end

  def photo_importer_params(photo)
    { method: :post, action: :image,
      api_key: inat_manager_key.key,
      upload_url: photo.url,

      copyright_holder: photo.copyright_holder,
      license: photo.license_id,
      notes: photo.notes,
      original_name: photo.original_name }
  end

  # Key for managing iNat imports; avoids requiring each user to have own key.
  # NOTE: Can this be done more elegantly via enviroment variable?
  # It now relies on duplicating the following in the live db & fixtures:
  # User with login: MO Webmaster, API_key with `notes: "inat import"`
  # 2024-06-18 jdc
  def inat_manager_key
    APIKey.where(user: @inat_manager, notes: "inat import").first
  end

  def update_names_and_proposals
    add_identifications_with_namings
    add_provisional_naming # iNat provisionals are not identifications
    adjust_consensus_name_naming # also adds naming for provisionals

    Observation::NamingConsensus.new(@observation).calc_consensus
  end

  def add_identifications_with_namings
    @inat_obs[:identifications].each do |identification|
      inat_taxon = ::Inat::Taxon.new(identification[:taxon])
      next if name_already_proposed?(inat_taxon.name)

      add_naming_with_vote(name: inat_taxon.name)
    end
  end

  def name_already_proposed?(name)
    Naming.where(observation_id: @observation.id).
      map(&:name).include?(name)
  end

  def add_naming_with_vote(name:, user: @inat_manager,
                           value: Vote::MAXIMUM_VOTE)
    naming = Naming.create(observation: @observation,
                           user: user, name: name)

    vote = Vote.create(naming: naming, observation: @observation,
                       user: user, value: value)
    # We need an ObservationView, but noone has actually viewed this Obs.
    ObservationView.create!(observation: @observation, user: user,
                            last_view: vote.updated_at, reviewed: 1)
  end

  def add_provisional_naming
    nom_prov = @inat_obs.provisional_name
    return if nom_prov.blank?

    # NOTE: There will be >= 1 match because of add_missing_provisional_name.
    # If a provisional Name was added during import, use it;
    # (It's the most recently created, and won't be deprecated.)
    # else grab another matching one.
    name = best_mo_homonym(nom_prov)
    add_naming_with_vote(name: name)
  end

  def best_mo_homonym(text_name)
    Name.where(text_name: text_name).
      order(deprecated: :asc, created_at: :desc).
      first
  end

  def adjust_consensus_name_naming
    naming = Naming.find_by(observation: @observation,
                            name: @observation.name)

    if naming.nil?
      add_naming_with_vote(name: @observation.name,
                           user: @inat_manager, value: Vote::MAXIMUM_VOTE)
    else
      vote = Vote.find_by(naming: naming, observation: @observation)
      vote.update(value: Vote::MAXIMUM_VOTE)
    end
  end

  def add_inat_sequences
    @inat_obs.sequences.each do |sequence|
      params = { action: :sequence, method: :post,
                 api_key: inat_manager_key.key,
                 observation: @observation.id,
                 locus: sequence[:locus],
                 bases: sequence[:bases],
                 archive: sequence[:archive],
                 accession: sequence[:accession],
                 notes: sequence[:notes] }

      # NOTE: Error handling? 2024-06-19 jdc.
      # https://github.com/MushroomObserver/mushroom-observer/issues/2382
      API2.execute(params)
    end
  end

  def add_snapshot_of_import_comment
    params = { target: @observation, user: @inat_manager,
               summary: "#{:inat_data_comment.t} #{@observation.created_at}",
               comment: @inat_obs.snapshot }
    Comment.create(params)
  end

  def update_inat_observation
    update_mushroom_observer_url_field
    sleep(1)
    update_description
  end

  def update_mushroom_observer_url_field
    update_inat_observation_field(observation_id: @observation.inat_id,
                                  field_id: 5005,
                                  value: "#{MO.http_domain}/#{@observation.id}")
  end

  def update_inat_observation_field(observation_id:, field_id:, value:)
    payload = { observation_field_value: { observation_id: observation_id,
                                           observation_field_id: field_id,
                                           value: value } }
    headers = { authorization: "Bearer #{@inat_import.token}",
                content_type: :json, accept: :json }
    response = RestClient.post("#{API_BASE}/observation_field_values",
                               payload.to_json, headers)
    JSON.parse(response.body)
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

  def increment_imported_count
    @inat_import.increment!(:imported_count)
  end

  def update_user_inat_username
    # Prevent MO users from setting their inat_username
    # to a non-existent iNat login
    return unless job_successful_enough?

    @inat_import.user.update(inat_username: @inat_import.inat_username)
  end

  # job successful enough to justify updating the MO user's iNat user_name
  def job_successful_enough?
    @inat_import.response_errors.empty? ||
      @inat_import.imported_count&.positive?
  end

  def log(str)
    time = Time.zone.now.to_s
    log_entry = "#{time}: InatImportJob #{@inat_import.id} #{str}"
    @inat_import.log ||= []
    @inat_import.log << log_entry
    @inat_import.save
  end
end
