# API
class API
  # API for Observation
  class ObservationAPI < ModelAPI
    self.model = Observation

    self.high_detail_page_length = 10
    self.low_detail_page_length  = 100
    self.put_page_length         = 1000
    self.delete_page_length      = 1000

    self.high_detail_includes = [
      :comments,
      :images,
      :location,
      :name,
      { namings: :name },
      :sequences,
      :user
    ]

    self.low_detail_includes = [
      :location,
      :name,
      :user
    ]

    # rubocop:disable Metrics/AbcSize
    def query_params
      {
        where:          sql_id_condition,
        created_at:     parse_time_range(:created_at),
        updated_at:     parse_time_range(:updated_at),
        date:           parse_date_range(:date),
        users:          parse_users(:user),
        names:          parse_strings(:name),
        synonym_names:  parse_strings(:synonyms_of),
        children_names: parse_strings(:children_of),
        locations:      parse_strings(:locations),
        # herbaria:     parse_strings(:herbaria),
        # specimen_ids: parse_strings(:specimen_ids),
        projects:       parse_strings(:projects),
        species_lists:  parse_strings(:species_lists),
        confidence:     parse_confidence,
        is_col_loc:     parse_boolean(:is_collection_location),
        has_specimen:   parse_boolean(:has_specimen),
        has_location:   parse_boolean(:has_location),
        has_notes:      parse_boolean(:has_notes),
        has_name:       parse_boolean(:has_name),
        has_images:     parse_boolean(:has_images),
        has_comments:   parse_boolean(:has_comments, limit: true),
        notes_has:      parse_string(:notes_has),
        comments_has:   parse_string(:comments_has),
        north:          parse_latitude(:north),
        south:          parse_latitude(:south),
        east:           parse_longitude(:east),
        west:           parse_longitude(:west)
      }
    end
    # rubocop:enable Metrics/AbcSize

    def create_params
      @name = parse_name(:name, default: Name.unknown)
      @vote = parse_float(:vote, default: Vote.maximum_vote)
      @log  = parse_boolean(:log, default: true)
      parse_herbarium_and_specimen!
      parse_location_and_coordinates!
      parse_images_and_pick_thumbnail
      {
        when:                   parse_date(:date, default: Date.today),
        notes:                  parse_notes(:notes),
        place_name:             @location,
        lat:                    @latitude,
        long:                   @longitude,
        alt:                    @altitude,
        specimen:               @has_specimen,
        is_collection_location: parse_is_collection_location,
        thumb_image:            @thumbnail,
        images:                 @images,
        projects:               parse_projects_to_attach_to,
        species_lists:          parse_species_lists_to_attach_to,
        name:                   @name
      }
    end

    def after_create(obs)
      create_specimen(obs) if obs.specimen
      naming = obs.namings.create(name: @name)
      obs.change_vote(naming, @vote, user)
      obs.log(:log_observation_created_at) if @log
    end

    def create_specimen(obs)
      provide_herbarium_default
      provide_herbarium_label_default(obs)
      obs.specimens << Specimen.create!(
        herbarium:       @herbarium,
        when:            Time.zone.now,
        user:            user,
        herbarium_label: @herbarium_label
      )
    end

    def provide_herbarium_default
      @herbarium ||= user.personal_herbarium || Herbarium.create!(
        name: user.personal_herbarium_name,
        personal_user: user
      )
    end

    def provide_herbarium_label_default(obs)
      @herbarium_label ||= Herbarium.default_specimen_label(
        @name.text_name, @specimen_id || obs.id
      )
    end

    def build_setter
      params = parse_parameters!
      lambda do |obj|
        must_have_edit_permission!(obj)
        obj.update!(params)
        update_images(obj)
        update_projects(obj)
        update_species_lists(obj)
      end
    end

    def update_images(obj)
      obj.images.push(*@add_imgs)      if @add_imgs.any?
      obj.images.delete(*@remove_imgs) if @remove_imgs.any?
    end

    def update_projects(obj)
      obj.projects.push(*@add_prjs)      if @add_prjs.any?
      obj.projects.delete(*@remove_prjs) if @remove_prjs.any?
    end

    def update_species_lists(obj)
      obj.species_lists.push(*@add_spls)      if @add_spls.any?
      obj.species_lists.delete(*@remove_spls) if @remove_spls.any?
    end

    def parse_parameters!
      parse_set_coordinates!
      parse_set_images!
      parse_set_projects!
      parse_set_species_lists!
      params = update_params
      params.remove_nils!
      raise MissingSetParameters.new if params.empty? && no_adds_or_removes?
      params
    end

    def no_adds_or_removes?
      @add_imgs.empty? && @remove_imgs.empty? &&
        @add_prjs.empty? && @remove_prjs.empty? &&
        @add_spls.empty? && @remove_spls.empty?
    end

    def update_params
      {
        when:                   parse_date(:set_date),
        notes:                  parse_string(:set_notes),
        place_name:             parse_place_name(:set_location, limit: 1024),
        lat:                    @latitude,
        long:                   @longitude,
        alt:                    @altitude,
        specimen:               parse_boolean(:set_has_specimen),
        is_collection_location: parse_boolean(:set_is_collection_location),
        thumb_image:            @thumbnail
      }
    end

    def parse_confidence
      limit = Range.new(Vote.minimum_vote, Vote.maximum_vote)
      parse_float_range(:confidence, limit: limit)
    end

    def parse_is_collection_location
      parse_boolean(:is_collection_location, default: true)
    end

    def parse_projects_to_attach_to
      parse_projects(:projects, must_be_member: true) || []
    end

    def parse_species_lists_to_attach_to
      parse_species_lists(:species_lists, must_have_edit_permission: true) || []
    end

    def parse_images_and_pick_thumbnail
      @images    = parse_images(:images) || []
      @thumbnail = parse_image(:thumbnail, default: @images.first)
      return if !@thumbnail || @images.include?(@thumbnail)
      @images.unshift(@thumbnail)
    end

    def parse_set_coordinates!
      @latitude  = parse_latitude(:set_latitude)
      @longitude = parse_longitude(:set_longitude)
      @altitude  = parse_altitude(:set_altitude)
      return unless @latitude && !@longitude || @longitude && !@latitude
      errors << LatLongMustBothBeSet.new
    end

    def parse_set_images!
      @thumbnail   = parse_image(:set_thumbnail)
      @add_imgs    = parse_images(:add_images) || []
      @remove_imgs = parse_images(:remove_images) || []
      return if !@thumbnail || @add_imgs.include?(@thumbnail)
      @add_imgs.unshift(@thumbnail)
    end

    def parse_set_projects!
      @add_prjs    = parse_projects(:add_projects) || []
      @remove_prjs = parse_projects(:remove_projects) || []
    end

    def parse_set_species_lists!
      @add_spls    = parse_species_lists(:add_species_lists) || []
      @remove_spls = parse_species_lists(:remove_species_lists) || []
    end

    def parse_location_and_coordinates!
      @location  = parse_place_name(:location, limit: 1024)
      @location  = Location.unknown.name if Location.is_unknown?(@location)
      @latitude  = parse_latitude(:latitude)
      @longitude = parse_longitude(:longitude)
      @altitude  = parse_altitude(:altitude)
      make_sure_both_latitude_and_longitude!
      make_sure_location_or_coordinates!
      @location ||= :UNKNOWN.l
    end

    def make_sure_both_latitude_and_longitude!
      return if @latitude && @longitude || !@longitude && !@latitude
      errors << LatLongMustBothBeSet.new
    end

    def make_sure_location_or_coordinates!
      return if @latitude || @location
      errors << MustSupplyLocationOrGPS.new
    end

    def parse_herbarium_and_specimen!
      @herbarium       = parse_herbarium(:herbarium, default: nil)
      @specimen_id     = parse_string(:specimen_id, default: nil)
      @herbarium_label = parse_string(:herbarium_label, default: nil)
      default          = @herbarium || @specimen_id || @herbarium_label || false
      @has_specimen    = parse_boolean(:has_specimen, default: default)
      make_sure_has_specimen_set!
      either_specimen_or_label!
    end

    def make_sure_has_specimen_set!
      return if @has_specimen
      error_class = CanOnlyUseThisFieldIfHasSpecimen
      errors << error_class.new(:herbarium)       if @herbarium
      errors << error_class.new(:specimen_id)     if @specimen_id
      errors << error_class.new(:herbarium_label) if @herbarium_label
    end

    def either_specimen_or_label!
      return unless @specimen_id && @herbarium_label
      errors << CanOnlyUseOneOfTheseFields.new(:specimen_id, :herbarium_label)
    end
  end
end
