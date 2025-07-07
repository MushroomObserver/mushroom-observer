# frozen_string_literal: true

class Inat
  # builds an MO Observation from an ::Inat::Obs
  class MoObservationBuilder
    attr_reader :inat_obs, :user

    def initialize(inat_obs:, user:)
      @inat_obs = inat_obs
      @user = user
    end

    def mo_observation
      create_observation
      add_external_link
      add_inat_images(@inat_obs[:observation_photos])
      update_names_and_proposals
      add_inat_sequences
      inat_obs
      @observation
    end

    def create_observation
      @observation = Observation.create(new_obs_params)
      # Ensure this Name wins consensus_calc ties
      # by creating this naming and vote first
      name = @observation.name
      naming_user =
        if suggested?(name) &&
           (suggester = User.find_by(inat_username: suggester(suggestion(name))))
          suggester
        else
          @user
        end
      add_naming_with_vote(name: @observation.name, user: naming_user)
      @observation.log(:log_observation_created)
    end

    def new_obs_params
      name_id = id_or_provisional_or_species_name
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
    def id_or_provisional_or_species_name
      return @inat_obs.name_id if @inat_obs.provisional_name.blank?

      parsed_prov_name = Name.parse_name(@inat_obs.provisional_name)

      if need_new_prov_name?(parsed_prov_name)
        name = add_provisional_name(parsed_prov_name)
        name.id
      else
        best_mo_homonym(parsed_prov_name.text_name).id
      end
    end

    def need_new_prov_name?(parsed_prov_name)
      Name.where(text_name: parsed_prov_name.text_name).none?
    end

    def add_external_link
      external_site = ExternalSite.find_by(name: "iNaturalist")
      ExternalLink.create(
        user: @user,
        observation: @observation,
        external_site: external_site,
        url: "#{external_site.base_url}#{@inat_obs[:id]}"
      )
    end

    def add_provisional_name(parsed_prov_name)
      params = { method: :post, action: :name,
                 api_key: @user_api_key,
                 name: parsed_prov_name.search_name,
                 rank: parsed_prov_name.rank }
      api = API2.execute(params)
      new_name = api.results.first
      new_name.log(:log_name_created)
      new_name
    end

    def add_inat_images(inat_obs_photos)
      inat_obs_photos.each do |obs_photo|
        photo = Inat::ObsPhoto.new(obs_photo)
        params = post_photo_params(photo)
        API2.execute(params)
      end
    end

    def post_photo_params(photo)
      {
        method: :post,
        action: :image,
        api_key: @user_api_key,

        upload_url: photo.url,
        notes: photo.notes,
        copyright_holder: photo.copyright_holder,
        license: photo.license_id,
        original_name: photo.original_name,
        observations: @observation.id
      }
    end

    def update_names_and_proposals
      adjust_consensus_name_naming # also adds naming for provisionals

      Observation::NamingConsensus.new(@observation).calc_consensus
    end

    def add_naming_with_vote(name:, user: @user,
                            value: Vote::MAXIMUM_VOTE)
      used_references = 2
      explanation = used_references_explanation(name)
      naming = Naming.create(
        observation: @observation,
        user: user, name: name,
        reasons: { used_references => explanation }
      )

      vote = Vote.create(naming: naming, observation: @observation,
                        user: user, value: value)
      # We need an ObservationView, but noone has actually viewed this Obs.
      ObservationView.create!(observation: @observation, user: user,
                              last_view: vote.updated_at, reviewed: 1)
    end

    def used_references_explanation(name)
      # If iNat has a provisional name, it's the id of the MO observation.
      if @inat_obs.provisional_name.present?
        nom_prov_adder = @inat_obs.inat_prov_name_field[:user][:login]
        # force it to be a String instead of an ActiveSupport::SafeBuffer
        # SafeBuffer causes an errors later on. Idk why. jdc 20241126
        :naming_inat_provisional.l(user: nom_prov_adder).to_str
      elsif suggested?(name)
        suggester_with_date(name)
      else
        "iNat `Community ID` #{Time.zone.today.strftime("%Y-%m-%d")}"
      end
    end

    def suggested?(name)
      inat_ids = @inat_obs[:identifications].map { |id| id[:taxon][:name] }
      inat_ids.include?(name.text_name)
    end

    def suggester_with_date(name)
      # The iNat user who suggested the name
      suggestion = suggestion(name)
      "#{:naming_reason_suggested_on_inat.l(user: suggester(suggestion))} " \
        "#{suggestion[:created_at]}"
    end

    def suggestion(name)
      @inat_obs[:identifications].
        find { |id| id[:taxon][:name] == name.text_name }
    end

    # iNat login of the iNat user who suggested the id on iNat
    def suggester(suggestion)
      suggestion[:user][:login]
    end

    def best_mo_homonym(text_name)
      Name.where(text_name: text_name).
        order(deprecated: :asc, created_at: :desc).
        first
    end

    def adjust_consensus_name_naming
      naming = Naming.find_by(observation: @observation,
                              name: @observation.name)
      vote = Vote.find_by(naming: naming, observation: @observation)
      vote.update(value: Vote::MAXIMUM_VOTE)
    end

    def add_inat_sequences
      @inat_obs.sequences.each do |sequence|
        params = { action: :sequence, method: :post,
                   api_key: @user_api_key,
                   observation: @observation.id,
                   locus: sequence[:locus],
                   bases: sequence[:bases],
                   archive: sequence[:archive],
                   accession: sequence[:accession],
                   notes: sequence[:notes] }
        API2.execute(params)
      end
    end

    def update_inat_observation
      update_mushroom_observer_url_field
      sleep(1)
      update_description
    end

    def update_mushroom_observer_url_field
      update_inat_observation_field(
        observation_id: @inat_obs[:id],
        # TODO: get rid of magic number
        field_id: 5005,
        value: "#{MO.http_domain}/#{@observation.id}"
      )
    end
  end
end
