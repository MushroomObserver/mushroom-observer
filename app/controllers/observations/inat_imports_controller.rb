# frozen_string_literal: true

# import iNaturalist Observations as MO Observations
#
# Work flow:
# 1. User calls `new`, fills out form
# 2. `create` saves tracking information in the iNatImport model
#    attributes include: user, inat_ids, token, state.
# 3. `create` redirects the user to iNat at the inat_authorization_url
# 4. user logs into iNat, authorizes MO to access user's confidential iNat data
# 5. upon authorization, iNat sends user to `authenticate` (the redirect_url)
# 6. MO continues in the `authenticate` action
#    Gets data from, and updates, InatImport
#    Trades the `code` which it received from iNat for a token
#    Makes an authenticated iNat API request search for the desired iNat obss
#    For each iNat obs in the search results, creates an InatObs and imports it
module Observations
  class InatImportsController < ApplicationController
    before_action :login_required
    before_action :pass_query_params

    # constants for iNat authorization and authentication
    # Where to redirect user for authorization
    SITE = "https://www.inaturalist.org"
    # Where iNat will send the code once authorized
    REDIRECT_URI =
      "http://localhost:3000/observations/inat_imports/authenticate"
    # iNat's id for the MO application
    APP_ID = Rails.application.credentials.inat.id
    # limit results of all iNat API requests
    ICONIC_TAXA = "Fungi,Protozoa"

    def new; end

    def create
      return username_required if params[:inat_username].blank?
      return reload_form if bad_inat_ids_param?
      return designation_required unless imports_designated?
      return consent_required if params[:consent] == "0"

      inat_import = InatImport.find_or_create_by(user: User.current)
      inat_import.update(state: "Authorizing",
                         import_all: params[:all],
                         inat_ids: params[:inat_ids],
                         inat_username: params[:inat_username])

      request_inat_user_authorization
    end

    # ---------------------------------

    private

    def reload_form
      @inat_ids = params[:inat_ids]
      @inat_username = params[:inat_username]
      render(:new)
    end

    def designation_required
      flash_warning(:inat_no_imports_designated.t)
      reload_form
    end

    def imports_designated?
      params[:all] == "1" || params[:inat_ids].present?
    end

    def consent_required
      flash_warning(:inat_consent_required.t)
      reload_form
    end

    def username_required
      flash_warning(:inat_missing_username.l)
      reload_form
    end

    def bad_inat_ids_param?
      contains_illegal_characters?
    end

    def contains_illegal_characters?
      return false unless /[^\d ,]/.match?(params[:inat_ids])

      flash_warning(:runtime_illegal_inat_id.l)
      true
    end

    def request_inat_user_authorization
      redirect_to(inat_authorization_url, allow_other_host: true)
    end

    def inat_authorization_url
      "https://www.inaturalist.org/oauth/authorize" \
      "?client_id=#{Rails.application.credentials.inat.id}" \
      "&redirect_uri=#{REDIRECT_URI}" \
      "&response_type=code"
    end

    # ---------------------------------

    public

    # iNat redirects here after user completes iNat authorization
    def authenticate
      auth_code = params[:code]
      return not_authorized if auth_code.blank?

      inat_import = InatImport.find_or_create_by(user: User.current)
      inat_import.update(state: "Authenticating")

      # exchange code received from iNat for an oAuth `access_token`
      payload = {
        client_id: APP_ID,
        client_secret: Rails.application.credentials.inat.secret,
        code: auth_code,
        redirect_uri: REDIRECT_URI,
        grant_type: "authorization_code"
      }
      oauth_response = RestClient.post("#{SITE}/oauth/token", payload)
      # The actual token is in the field ["access_token"].
      access_token = JSON.parse(oauth_response.body)["access_token"]

      # Use the `access_token` to request a `jwt`, right away.
      jwt_response = RestClient::Request.execute(
        method: :get, url: "https://www.inaturalist.org/users/api_token",
        headers: { authorization: "Bearer #{access_token}", accept: :json }
      )
      api_token = JSON.parse(jwt_response)["api_token"]

      # Now that we've got the right token, we can make authenticated requests
      # to iNat that get the real real private data.
      inat_import.update(token: api_token, state: "Importing")

      import_requested_observations(inat_import)

      inat_import.update(state: "Done")
      redirect_to(observations_path)
    end

    # ---------------------------------

    private

    def not_authorized
      flash_error(:inat_no_authorization.l)
      redirect_to(observations_path)
    end

    def import_requested_observations(inat_import)
      inat_ids = inat_id_list(inat_import)
      return if inat_import[:import_all].blank? && inat_ids.blank?

      last_import_id = 0
      loop do
        page =
          inat_search_observations(
            ids: inat_ids, id_above: last_import_id,
            user_login: inat_import.inat_username
          )
        break if page_empty?(page)

        import_page(page)
        parsed_page = JSON.parse(page)
        last_import_id = parsed_page["results"].last["id"]
        break if done_with_page?(parsed_page)

        next
      end
    end

    def page_empty?(page)
      JSON.parse(page)["total_results"].zero?
    end

    def done_with_page?(parsed_page)
      parsed_page["total_results"] <=
        parsed_page["page"] * parsed_page["per_page"]
    end

    def inat_id_list(inat_import)
      inat_import.inat_ids.delete(" ")
    end

    # https://api.inaturalist.org/v1/docs/#!/Observations/get_observations
    # https://stackoverflow.com/a/11251654/3357635
    # Note that the `ids` parameter may be a comma-separated list of iNat obs
    # ids - that needs to be URL encoded to a string when passed as an arg here
    # because URI.encode_www_form deals with arrays by passing the same key
    # multiple times.
    def inat_search_observations(**args)
      query_args = {
        ids: nil, id_above: nil, only_id: false, per_page: 200,
        order: "asc", order_by: "id",
        # prevents user from importing others' obss
        user_login: nil, iconic_taxa: ICONIC_TAXA
      }.merge(args)

      query = URI.encode_www_form(query_args)
      ::Inat.new(operation: query, token: inat_import.token).body
    end

    def import_page(page)
      JSON.parse(page)["results"].each do |result|
        import_one_result(JSON.generate(result))
      end
    end

    def import_one_result(result)
      inat_obs = InatObs.new(result)
      return not_importable(inat_obs) unless inat_obs.importable?

      @observation = Observation.create(
        when: inat_obs.when,
        location: inat_obs.location,
        where: inat_obs.where,
        lat: inat_obs.lat,
        lng: inat_obs.lng,
        gps_hidden: inat_obs.gps_hidden,
        name_id: inat_obs.name_id,
        text_name: inat_obs.text_name,
        notes: inat_obs.notes,
        source: "mo_inat_import",
        inat_id: inat_obs.inat_id
      )
      @observation.log(:log_observation_created)

      # NOTE: 2024-06-19 jdc. I can't figure out how to properly stub
      # adding an image from an external source.
      # Skipping images when testing will allow some more controller testing.
      # add_inat_images(inat_obs.inat_obs_photos) unless Rails.env.test?
      add_inat_images(inat_obs.inat_obs_photos)
      update_names_and_proposals(inat_obs)
      add_inat_sequences(inat_obs)
      add_inat_summmary_data(inat_obs)
      # TODO: Other things done by Observations#create
      # save_everything_else(params.dig(:naming, :reasons))
      # strip_images! if @observation.gps_hidden
      # update_field_slip(@observation, params[:field_code])
    end

    def inat_import
      InatImport.find_by(user: User.current)
    end

    def not_importable(inat_obs)
      return if inat_obs.taxon_importable?

      flash_error(:inat_taxon_not_importable.t(id: inat_obs.inat_id))
    end

    def add_inat_images(inat_obs_photos)
      inat_obs_photos.each do |obs_photo|
        photo = InatObsPhoto.new(obs_photo)
        # ImageAPI#create params to consider adding to API params below
        # projects: parse_array(:project, :projects, must_be_member: true) ||
        #           [],
        params = {
          method: :post,
          action: :image,
          api_key: inat_manager_key.key,
          upload_url: photo.url,

          copyright_holder: photo.copyright_holder,
          license: photo.license_id,
          notes: photo.notes,
          original_name: photo.original_name
        }

        api = InatPhotoImporter.new(params).api
        User.current = @user # API call zaps User.current
        # TODO: Error handling? 2024-06-19 jdc.

        image = Image.find(api.results.first.id)

        # Imaage attributes to potentially update manually
        # t.boolean "ok_for_export", default: true, null: false
        # t.boolean "gps_stripped", default: false, null: false
        # t.boolean "diagnostic", default: true, null: false
        image.update(
          user_id: User.current.id, # throws Error if done as API param above
          # TODO: get date from EXIF; it could be > obs date
          when: @observation.when # throws Error if done as API param above
        )
        @observation.add_image(image)
      end
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
      add_namings_for_identifications(inat_obs)
      add_provisional_name(inat_obs) # iNat provisional are not identifications
      adjust_consensus_name_naming # also adds naming for provisionals
    end

    def add_namings_for_identifications(inat_obs)
      inat_obs.inat_identifications.each do |identification|
        inat_taxon = ::InatTaxon.new(identification[:taxon])
        next if name_already_proposed?(inat_taxon.name)

        add_naming_with_vote(name: inat_taxon.name,
                             user: naming_user(identification), value: 0)
      end
    end

    def name_already_proposed?(name)
      Naming.where(observation_id: @observation.id).
        map(&:name).include?(name)
    end

    def naming_user(identification)
      importer =
        InatImport.where(user_id: User.current.id).first.inat_username

      if identification[:user][:login] == importer
        User.current
      else
        # iNat user who made this identification might not be an MO User
        # So make inat_manager the user for the Proposed Name
        inat_manager
      end
    end

    def add_naming_with_vote(name:, user: User.current, value: 0)
      naming = Naming.create(observation: @observation,
                             user: user,
                             name: name)

      Vote.create(naming: naming, observation: @observation,
                  user: user, value: value)
    end

    def add_provisional_name(inat_obs)
      nom_prov = inat_obs.provisional_name
      return if nom_prov.blank?

      mo_counterparts = Name.where(text_name: nom_prov)
      # Don't try to resolve if many MO names have this text name
      return if mo_counterparts.many?

      name = if mo_counterparts.one?
               mo_counterparts.first
             else
               params = {
                 method: :post,
                 action: :name,
                 api_key: inat_manager_key.key,
                 name: "#{nom_prov} crypt. temp.",
                 rank: "Species"
               }
               api = API2.execute(params)
               User.current = @user # API call zaps User.current

               new_name = api.results.first
               new_name.log(:log_name_created)
               new_name
             end
      # If iNat obs has a provisional name, treat it as the MO consensus;
      # let the calling method (add_namings) add a Naming and Vote
      @observation.update(name: name, text_name: nom_prov)
    end

    def adjust_consensus_name_naming
      naming = Naming.find_by(observation: @observation,
                              name: @observation.name)

      if naming.nil?
        add_naming_with_vote(name: @observation.name,
                             user: inat_manager, value: 1)
      else
        vote = Vote.find_by(naming: naming, observation: @observation)
        vote.update(value: 1)
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

        # TODO: Error handling? 2024-06-19 jdc.
        api = API2.execute(params)
        User.current = @user # API call zaps User.current
      end
    end

    def obs_fields(fields)
      fields.map do |field|
        "&nbsp;&nbsp;#{field[:name]}: #{field[:value]}"
      end.join("\n")
    end

    def add_inat_summmary_data(inat_obs)
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
end
