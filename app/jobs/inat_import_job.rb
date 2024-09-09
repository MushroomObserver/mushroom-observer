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

  queue_as :default

  def perform(inat_import)
    @inat_import = inat_import

    access_token =
      use_auth_code_to_obtain_oauth_access_token(@inat_import.token)
    @inat_import.update(token: access_token)

    api_token = trade_access_token_for_jwt_api_token(@inat_import.token)
    @inat_import.update(token: api_token, state: "Importing")

    import_requested_observations

    @inat_import.update(state: "Done")
  end

  private

  # https://www.inaturalist.org/pages/api+reference#authorization_code_flow
  def use_auth_code_to_obtain_oauth_access_token(auth_code)
    payload = {
      client_id: APP_ID,
      client_secret: Rails.application.credentials.inat.secret,
      code: auth_code,
      redirect_uri: REDIRECT_URI,
      grant_type: "authorization_code"
    }
    oauth_response = RestClient.post("#{SITE}/oauth/token", payload)
    JSON.parse(oauth_response.body)["access_token"]
  end

  # https://www.inaturalist.org/pages/api+recommended+practices
  def trade_access_token_for_jwt_api_token(access_token)
    jwt_response = RestClient::Request.execute(
      method: :get, url: "#{SITE}/users/api_token",
      headers: { authorization: "Bearer #{access_token}", accept: :json }
    )
    JSON.parse(jwt_response)["api_token"]
  end

  def import_requested_observations
    inat_ids = inat_id_list
    return if @inat_import[:import_all].blank? && inat_ids.blank?

    # Search for one page of results at a time, until done with all pages
    # To get one page, use iNats `per_page` & `id_above` params.
    # https://api.inaturalist.org/v1/docs/#!/Observations/get_observations
    last_import_id = 0
    loop do
      page_of_observations =
        # get a page of observations with id > id of last imported obs
        next_page(
          id: inat_ids, id_above: last_import_id,
          user_login: @inat_import.inat_username
        )
      parsed_page = JSON.parse(page_of_observations)
      break if page_empty?(parsed_page)

      import_page(page_of_observations)

      last_import_id = parsed_page["results"].last["id"]
      next unless last_page?(parsed_page)

      break
    end
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

  # This is where we actually hit the iNat API
  # https://api.inaturalist.org/v1/docs/#!/Observations/get_observations
  # https://stackoverflow.com/a/11251654/3357635
  # Note that the `ids` parameter may be a comma-separated list of iNat obs
  # ids - that needs to be URL encoded to a string when passed as an arg here
  # because URI.encode_www_form deals with arrays by passing the same key
  # multiple times.
  def next_page(**args)
    query_args = {
      id: nil, id_above: nil, only_id: false, per_page: 200,
      order: "asc", order_by: "id",
      # prevents user from importing others' obss
      user_login: nil, iconic_taxa: ICONIC_TAXA
    }.merge(args)

    query = URI.encode_www_form(query_args)
    # ::Inat.new(operation: query, token: @inat_import.token).body

    # Nimmo 2024-06-19 jdc. Moving the request from the inat class to here.
    # RestClient::Request.execute wasn't available in the class
    headers = { authorization: "Bearer #{@inat_import.token}", accept: :json }
    @inat = RestClient::Request.execute(
      method: :get, url: "#{API_BASE}/observations?#{query}", headers: headers
    )
  end

  def import_page(page)
    JSON.parse(page)["results"].each do |result|
      import_one_result(JSON.generate(result))
    end
  end

  def import_one_result(result)
    inat_obs = InatObs.new(result)
    return unless inat_obs.importable?

    create_observation(inat_obs)
    add_inat_images(inat_obs.inat_obs_photos)
    update_names_and_proposals(inat_obs)
    add_inat_sequences(inat_obs)
    add_import_snapshot_comment(inat_obs)
  end

  def create_observation(inat_obs)
    name_id = adjust_for_provisional(inat_obs)

    @observation = Observation.create(
      user: @inat_import.user,
      when: inat_obs.when,
      location: inat_obs.location,
      where: inat_obs.where,
      lat: inat_obs.lat,
      lng: inat_obs.lng,
      gps_hidden: inat_obs.gps_hidden,
      name_id: name_id,
      text_name: Name.find(name_id).text_name,
      notes: inat_obs.notes,
      source: "mo_inat_import",
      inat_id: inat_obs.inat_id
    )
    # Ensure this Name wins consensus_calc ties
    # by creating this naming and vote first
    add_naming_with_vote(name: @observation.name)
    @observation.log(:log_observation_created)
  end

  # NOTE: 1. iNat users seem to add a prov name only if there's a sequence.
  #  2. iNat cannot use a prov name as the iNat identication.
  # So if iNat has a provisional name observation field, then
  #   add an MO provisional name if none exists, and
  #   treat the provisional name as the MO consensus.
  def adjust_for_provisional(inat_obs)
    prov_name = inat_obs.provisional_name
    return inat_obs.name_id if prov_name.blank?

    if need_new_prov_name?(prov_name)
      name = add_provisional_name(prov_name)
      name.id
    else
      best_mo_homonym(prov_name).id
    end
  end

  def need_new_prov_name?(prov_name)
    prov_name.blank? ||
      Name.where(text_name: prov_name).none?
  end

  def add_provisional_name(prov_name)
    params = {
      method: :post,
      action: :name,
      api_key: inat_manager_key.key,
      name: "#{prov_name} crypt. temp.",
      rank: "Species"
    }
    api = API2.execute(params)

    new_name = api.results.first
    new_name.log(:log_name_created)
    new_name
  end

  def add_inat_images(inat_obs_photos)
    inat_obs_photos.each do |obs_photo|
      photo = InatObsPhoto.new(obs_photo)
      api = InatPhotoImporter.new(photo_importer_params(photo)).api
      # NOTE: Error handling? 2024-06-19 jdc.
      # https://github.com/MushroomObserver/mushroom-observer/issues/2382

      image = Image.find(api.results.first.id)

      # Imaage attributes to potentially update manually
      # t.boolean "ok_for_export", default: true, null: false
      # t.boolean "gps_stripped", default: false, null: false
      # t.boolean "diagnostic", default: true, null: false
      image.update(
        user_id: @inat_import.user_id, # throws Error if done as API param above
        when: @observation.when # throws Error if done as API param above
      )
      @observation.add_image(image)
    end
  end

  def photo_importer_params(photo)
    {
      method: :post,
      action: :image,
      api_key: inat_manager_key.key,
      upload_url: photo.url,

      copyright_holder: photo.copyright_holder,
      license: photo.license_id,
      notes: photo.notes,
      original_name: photo.original_name
    }
  end

  # Key for managing iNat imports; avoids requiring each user to have own key.
  # NOTE: Can this be done more elegantly via enviroment variable?
  # It now relies on duplicating the following in the live db & fixtures:
  # User with login: MO Webmaster, API_key with `notes: "inat import"`
  # 2024-06-18 jdc
  def inat_manager_key
    APIKey.where(user: inat_manager, notes: "inat import").first
  end

  def inat_manager
    User.find_by(login: "MO Webmaster")
  end

  def update_names_and_proposals(inat_obs)
    add_identifications_with_namings(inat_obs)
    add_provisional_naming(inat_obs) # iNat provisionals are not identifications
    adjust_consensus_name_naming # also adds naming for provisionals

    Observation::NamingConsensus.new(@observation).calc_consensus
  end

  def add_identifications_with_namings(inat_obs)
    inat_obs.inat_identifications.each do |identification|
      inat_taxon = ::InatTaxon.new(identification[:taxon])
      next if name_already_proposed?(inat_taxon.name)

      add_naming_with_vote(name: inat_taxon.name)
    end
  end

  def name_already_proposed?(name)
    Naming.where(observation_id: @observation.id).
      map(&:name).include?(name)
  end

  def add_naming_with_vote(name:, user: inat_manager, value: Vote::MAXIMUM_VOTE)
    naming = Naming.create(observation: @observation,
                           user: user, name: name)

    Vote.create(naming: naming, observation: @observation,
                user: user, value: value)
  end

  def add_provisional_naming(inat_obs)
    nom_prov = inat_obs.provisional_name
    return if nom_prov.blank?

    # NOTE: There will be >= 1 match because of add_missing_provisional_name.
    # If a provisional Name was added during import, use it;
    # it's the most recently created, and won't be deprecated.
    # Else grab another mathcing one.
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
                           user: inat_manager, value: Vote::MAXIMUM_VOTE)
    else
      vote = Vote.find_by(naming: naming, observation: @observation)
      vote.update(value: Vote::MAXIMUM_VOTE)
    end
  end

  def lat_lon_accuracy(inat_obs)
    "#{inat_obs.inat_location} " \
    "+/-#{inat_obs.inat_public_positional_accuracy} m"
  end

  def add_inat_sequences(inat_obs)
    inat_obs.sequences.each do |sequence|
      params = {
        action: :sequence,
        method: :post,
        api_key: inat_manager_key.key,
        observation: @observation.id,
        locus: sequence[:locus],
        bases: sequence[:bases],
        archive: sequence[:archive],
        accession: sequence[:accession],
        notes: sequence[:notes]
      }

      # NOTE: Error handling? 2024-06-19 jdc.
      # https://github.com/MushroomObserver/mushroom-observer/issues/2382
      API2.execute(params)
    end
  end

  def obs_fields(fields)
    fields.map do |field|
      "&nbsp;&nbsp;#{field[:name]}: #{field[:value]}"
    end.join("\n")
  end

  def add_import_snapshot_comment(inat_obs)
    params = {
      target: @observation,
      summary: "#{:inat_data_comment.t} #{@observation.created_at}",
      comment: comment(inat_obs),
      user: inat_manager
    }

    Comment.create(params)
  end

  def comment(inat_obs)
    <<~COMMENT.gsub(/^\s+/, "")
      #{:USER.t}: #{inat_obs.inat_user_login}
      #{:OBSERVED.t}: #{inat_obs.when}\n
      #{:LAT_LON.t}: #{lat_lon_accuracy(inat_obs)}\n
      #{:PLACE.t}: #{inat_obs.inat_place_guess}\n
      #{:ID.t}: #{inat_obs.inat_taxon_name}\n
      #{:DQA.t}: #{inat_obs.dqa}\n
      #{:ANNOTATIONS.t}: #{:UNDER_DEVELOPMENT.t}\n
      #{:PROJECTS.t}: #{inat_obs.inat_project_names}\n
      #{:SEQUENCES.t}: #{:UNDER_DEVELOPMENT.t}\n
      #{:OBSERVATION_FIELDS.t}: \n\

      #{obs_fields(inat_obs.inat_obs_fields)}\n
      #{:TAGS.t}: #{inat_obs.inat_tags.join(" ")}\n
    COMMENT
  end
end
