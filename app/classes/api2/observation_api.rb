# frozen_string_literal: true

class API2
  # API for Observation
  # rubocop:disable Metrics/ClassLength
  class ObservationAPI < ModelAPI
    def model
      Observation
    end

    def high_detail_page_length
      100
    end

    def low_detail_page_length
      1000
    end

    def put_page_length
      1000
    end

    def delete_page_length
      1000
    end

    def high_detail_includes
      [
        :collection_numbers,
        { comments: :user },
        :external_links,
        { herbarium_records: :herbarium },
        { images: [:license, :user] },
        :location,
        :name,
        { namings: [:name, :user] },
        :sequences,
        :user,
        { votes: :user }
      ]
    end

    def query_params
      box = parse_bounding_box!
      {
        id_in_set: parse_array(:observation, :id, as: :id),
        created_at: parse_range(:time, :created_at),
        updated_at: parse_range(:time, :updated_at),
        date: parse_range(:date, :date, help: :when_seen),
        by_users: parse_array(:user, :user, help: :observer),
        names: parse_array(:name, :name, as: :id),
        locations: parse_array(:location, :location, as: :id),
        herbaria: parse_array(:herbarium, :herbarium, as: :id),
        herbarium_records: parse_array(:herbarium_record, :herbarium_record,
                                       as: :id),
        projects: parse_array(:project, :project, as: :id),
        species_lists: parse_array(:species_list, :species_list, as: :id),
        confidence: parse(:confidence, :confidence),
        is_collection_location: parse(:boolean, :is_collection_location,
                                      help: 1),
        gps_hidden: parse(:boolean, :gps_hidden, help: 1),
        has_images: parse(:boolean, :has_images),
        has_public_lat_lng: parse(:boolean, :has_public_lat_lng),
        has_name: parse(:boolean, :has_name, help: :min_rank),
        has_comments: parse(:boolean, :has_comments, limit: true),
        has_specimen: parse(:boolean, :has_specimen),
        has_notes: parse(:boolean, :has_notes),
        has_notes_fields: parse_array(:string, :has_notes_field, help: 1),
        notes_has: parse(:string, :notes_has, help: 1),
        comments_has: parse(:string, :comments_has, help: 1),
        in_box: box,
        region: parse(:string, :region, help: 1)
      }.merge(parse_names_parameters)
    end

    def create_params
      parse_create_params!
      {
        when: parse(:date, :date) || Time.zone.today,
        place_name: @location,
        lat: @latitude,
        lng: @longitude,
        alt: @altitude,
        specimen: @has_specimen,
        is_collection_location: parse(:boolean, :is_collection_location,
                                      default: true, help: 1),
        gps_hidden: parse(:boolean, :gps_hidden, default: false,
                                                 help: 1),
        notes: @notes,
        source: parse(:enum, :source, limit: Observation.sources.keys,
                                      default: "mo_api"),
        thumb_image: @thumbnail,
        images: @images,
        projects: parse_array(:project, :projects, must_be_member: true) || [],
        species_lists: parse_array(:species_list, :species_lists,
                                   must_have_edit_permission: true) || [],
        name: @name,
        user: @user
      }
    end

    def update_params
      parse_update_params!
      {
        when: parse(:date, :set_date),
        place_name: parse(:place_name, :set_location, limit: 1024,
                                                      not_blank: true),
        lat: @latitude,
        lng: @longitude,
        alt: @altitude,
        specimen: parse(:boolean, :set_has_specimen),
        is_collection_location: parse(:boolean, :set_is_collection_location,
                                      help: 1),
        gps_hidden: parse(:boolean, :gps_hidden, help: 1),
        thumb_image: @thumbnail
      }
    end

    def validate_create_params!(params)
      make_sure_both_latitude_and_longitude!
      make_sure_has_specimen_set!
      make_sure_location_provided!
      check_for_unknown_location!(params)
    end

    def after_create(obs)
      obs.user_log(user, :log_observation_created) if @log
      create_specimen_records(obs) if obs.specimen
      create_naming(obs)
      add_field_slip_code(obs)
    end

    def validate_update_params!(params)
      check_for_unknown_location!(params)
      raise(MissingSetParameters.new) if params.empty? && no_adds_or_removes?
    end

    def build_setter(params)
      lambda do |obs|
        must_have_edit_permission!(obs)
        update_notes_fields(obs)
        obs.update!(params)
        update_images(obs)
        update_projects(obs)
        update_species_lists(obs)
        obs.log(:log_observation_updated) if @log
        obs
      end
    end

    ############################################################################

    private

    def create_naming(obs)
      naming = obs.namings.new(name: @name)
      naming.reasons_array.each do |reason|
        if @reasons[reason.num].nil?
          reason.delete
        else
          reason.notes = @reasons[reason.num]
        end
      end
      naming.user ||= @user
      naming.save!
      consensus = ::Observation::NamingConsensus.new(obs)
      consensus.change_vote(naming, @vote, user)
    end

    def add_field_slip_code(observation)
      return unless @code

      field_slip = FieldSlip.find_by(code: @code)
      if field_slip
        raise(FieldSlipInUse.new(field_slip)) if field_slip.observation

        field_slip.update!(observation:)
      else
        field_slip = FieldSlip.create!(observation:, code: @code)
        field_slip.current_user = @user
        field_slip.update_project
        field_slip.save!
      end
      update_project(field_slip.project, observation)
    end

    def update_project(project, observation)
      return unless project && !project.violates_constraints?(observation)

      user = observation.user
      project.join(user)
      return unless project.member?(user)

      project.add_observation(observation)
    end

    def create_specimen_records(obs)
      provide_specimen_defaults(obs)
      if @collection_number
        CollectionNumber.create!(
          user: user,
          name: @collectors_name,
          number: @collection_number
        ).add_observation(obs)
      end
      return unless @herbarium

      HerbariumRecord.create!(
        herbarium: @herbarium,
        user: user,
        initial_det: @initial_det,
        accession_number: @accession_number
      ).add_observation(obs)
    end

    def provide_specimen_defaults(obs)
      @herbarium        ||= user.personal_herbarium ||
                            user.create_personal_herbarium
      @collectors_name  ||= user.legal_name
      @initial_det      ||= @name.text_name
      # Disable cop because we're creating a bunch of instance variables,
      # rather than trying to memoize provide_specimen_defaults
      # rubocop:disable Naming/MemoizedInstanceVariableName
      @accession_number ||= if @collection_number
                              "#{@collectors_name} #{@collection_number}"
                            else
                              "MO #{obs.id}"
                            end
      # rubocop:enable Naming/MemoizedInstanceVariableName
    end

    def update_notes_fields(obs)
      @notes.each do |key, val|
        if val.blank?
          obs.notes.delete(key)
        else
          obs.notes[key] = val
        end
      end
    end

    def update_images(obs)
      @add_images.each do |img|
        obs.images << img unless obs.images.include?(img)
      end
      obs.images.delete(*@remove_images)
      return unless @remove_images.include?(obs.thumb_image)

      obs.update!(thumb_image: obs.images.first)
    end

    def update_projects(obs)
      return unless @add_to_project || @remove_from_project
      raise(MustBeOwner.new(obs)) if obs.user != @user

      obs.projects.push(@add_to_project) if @add_to_project
      obs.projects.delete(@remove_from_project) if @remove_from_project
    end

    def update_species_lists(obs)
      obs.species_lists.push(@add_to_list)        if @add_to_list
      obs.species_lists.delete(@remove_from_list) if @remove_from_list
    end

    # --------------------
    #  Parsing
    # --------------------

    def parse_create_params!
      @name    = parse(:name, :name, default: Name.unknown)
      @vote    = parse(:float, :vote, default: Vote.maximum_vote)
      @log     = parse(:boolean, :log, default: true, help: 1)
      @code    = parse(:string, :code)
      @notes   = parse_notes_fields!
      @reasons = parse_naming_reasons!
      parse_herbarium_and_specimen!
      parse_location_and_coordinates!
      parse_images_and_pick_thumbnail
    end

    def parse_update_params!
      @log = parse(:boolean, :log, default: true, help: 1)
      parse_set_coordinates!
      parse_set_images!
      parse_set_projects!
      parse_set_species_lists!
      @notes = parse_notes_fields!(set: true)
    end

    def parse_images_and_pick_thumbnail
      @images    = parse_array(:image, :images) || []
      @thumbnail = parse(:image, :thumbnail) || @images.first
      return if !@thumbnail || @images.include?(@thumbnail)

      @images.unshift(@thumbnail)
    end

    def parse_notes_fields!(set: false)
      prefix = set ? "set_" : ""
      notes = look_for_note_field_parameters(prefix)
      other = parse(:string, :"#{prefix}notes")
      notes[Observation.other_notes_key] = other unless other.nil?
      declare_parameter(:"#{prefix}notes[$field]", :string, help: :notes_field)
      return notes if set

      notes.compact_blank!
    end

    def look_for_note_field_parameters(prefix)
      notes = Observation.no_notes
      params.each do |key, val|
        next unless (match = key.to_s.match(/^#{prefix}notes\[(.*)\]$/))

        field = parse_notes_field_parameter!(match[1])
        notes[field] = val.to_s.strip
        ignore_parameter(key)
      end
      notes
    end

    def parse_notes_field_parameter!(str)
      keys = User.parse_notes_template(str)
      return keys.first.to_sym if keys.length == 1

      raise(BadNotesFieldParameter.new(str))
    end

    def parse_naming_reasons!
      Naming::Reason.all_reasons.each_with_object({}) do |num, reasons|
        val = parse(:string, :"reason_#{num}")
        val = nil if val == "."
        reasons[num] = val
      end
    end

    def parse_set_coordinates!
      @latitude  = parse(:latitude, :set_latitude)
      @longitude = parse(:longitude, :set_longitude)
      @altitude  = parse(:altitude, :set_altitude)
      return unless @latitude && !@longitude || @longitude && !@latitude

      raise(LatLongMustBothBeSet.new)
    end

    def parse_set_images!
      @thumbnail     = parse(:image, :set_thumbnail,
                             must_have_edit_permission: true)
      @add_images    = parse_array(:image, :add_images,
                                   must_have_edit_permission: true) || []
      @remove_images = parse_array(:image, :remove_images) || []
      return if !@thumbnail || @add_images.include?(@thumbnail)

      @add_images.unshift(@thumbnail)
    end

    def parse_set_projects!
      @add_to_project      = parse(:project, :add_to_project,
                                   must_be_member: true)
      @remove_from_project = parse(:project, :remove_from_project)
    end

    def parse_set_species_lists!
      @add_to_list      = parse(:species_list, :add_to_species_list,
                                must_have_edit_permission: true)
      @remove_from_list = parse(:species_list, :remove_from_species_list,
                                must_have_edit_permission: true)
    end

    def parse_location_and_coordinates!
      @location  = parse(:place_name, :location, limit: 1024)
      @latitude  = parse(:latitude, :latitude)
      @longitude = parse(:longitude, :longitude)
      @altitude  = parse(:altitude, :altitude)
      prefer_minimum_bounding_box_to_earth!
    end

    def prefer_minimum_bounding_box_to_earth!
      return unless Location.is_unknown?(@location) &&
                    @latitude.present? && @longitude.present?

      mbb =
        Location.with_minimum_bounding_box_containing_point(
          lat: @latitude, lng: @longitude
        ).
        # See comment at Observation#prefer_minimum_bounding_box_to_earth
        presence || Location.unknown
      @location = mbb.name
    end

    def parse_herbarium_and_specimen!
      @herbarium         = parse(:herbarium, :herbarium)
      @collectors_name   = parse(:string, :collectors_name)
      @collection_number = parse(:string, :collection_number)
      @initial_det       = parse(:string, :initial_det, help: 1)
      @accession_number  = parse(:string, :accession_number, help: 1)
      default            = @herbarium || @collection_number ||
                           @accession_number || false
      @has_specimen      = parse(:boolean, :has_specimen)
      @has_specimen      = default if @has_specimen.nil?
    end

    # --------------------
    #  Validation
    # --------------------

    def no_adds_or_removes?
      @add_images.empty? && @remove_images.empty? &&
        !@add_to_project && !@remove_from_project &&
        !@add_to_list && !@remove_from_list &&
        @notes.empty?
    end

    def make_sure_both_latitude_and_longitude!
      return if @latitude && @longitude || !@longitude && !@latitude

      raise(LatLongMustBothBeSet.new)
    end

    def make_sure_has_specimen_set!
      return if @has_specimen

      error_class = CanOnlyUseThisFieldIfHasSpecimen
      raise(error_class.new(:herbarium))         if @herbarium
      raise(error_class.new(:collectors_name))   if @collectors_name
      raise(error_class.new(:collection_number)) if @collection_number
      raise(error_class.new(:initial_det))       if @initial_det
      raise(error_class.new(:accession_number))  if @accession_number
    end

    def make_sure_location_provided!
      raise(MissingParameter.new(:location)) unless @location
    end

    def check_for_unknown_location!(params)
      place = params[:place_name]
      return unless place && Location.is_unknown?(place)

      params[:place_name] = Location.unknown.name
    end
  end
  # rubocop:enable Metrics/ClassLength
end
