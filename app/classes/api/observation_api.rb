# encoding: utf-8
# API for Observation model
class API
  # query, create, and modify an Observation
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
      :user
    ]

    self.low_detail_includes = [
      :location,
      :name,
      :user
    ]

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
        confidence:     parse_float_range(
          :confidence,
          limit: Range.new(Vote.minimum_vote, Vote.maximum_vote)
        ),
        is_col_loc:     parse_boolean(:is_collection_location),
        has_specimen:  parse_boolean(:has_specimen),
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

    def create_params
      @name = parse_name(:name, default: Name.unknown)
      @vote = parse_float(:vote, default: Vote.maximum_vote)
      @log  = parse_boolean(:log, default: true)

      @herbarium = parse_herbarium(:herbarium, default: nil)
      @specimen_id = parse_string(:specimen_id, default: nil)
      @herbarium_label = parse_string(:herbarium_label, default: nil)
      has_specimen = parse_boolean(
        :has_specimen,
        default: @herbarium || @specimen_id || @herbarium_label || false
      )
      unless has_specimen
        errors << CanOnlyUseThisFieldIfHasSpecimen.new(:herbarium) if @herbarium
        if @specimen_id
          errors << CanOnlyUseThisFieldIfHasSpecimen.new(:specimen_id)
        end
        if @herbarium_label
          errors << CanOnlyUseThisFieldIfHasSpecimen.new(:herbarium_label)
        end
      end
      errors << CanOnlyUseOneOfTheseFields.new(:specimen_id, :herbarium_label) \
        if @specimen_id && @herbarium_label

      loc = parse_place_name(:location, limit: 1024)
      loc = Location.unknown.name if Location.is_unknown?(loc)
      lat = parse_latitude(:latitude)
      long = parse_longitude(:longitude)
      alt = parse_altitude(:altitude)
      if !lat != !long
        errors << LatLongMustBothBeSet.new
        lat = long = nil
      end
      errors << MustSupplyLocationOrGPS.new if !lat && !loc
      loc ||= :UNKNOWN.l

      images = parse_images(:images, default: [])
      thumbnail = parse_image(:thumbnail, default: images.first)
      images.unshift(thumbnail) if thumbnail && !images.include?(thumbnail)
      {
        when: parse_date(:date, default: Date.today),
        notes: parse_notes(:notes),
        place_name: loc,
        lat: lat,
        long: long,
        alt: alt,
        specimen: has_specimen,
        is_collection_location: parse_boolean(
          :is_collection_location, default: true
        ),
        thumb_image: thumbnail,
        images: images,
        projects: parse_projects(:projects, default: [], must_be_member: true),
        species_lists: parse_species_lists(
          :species_lists, default: [], must_have_edit_permission: true
        ),
        name: @name
      }
    end

    def validate_create_params!(_params)
    end

    def after_create(obs)
      create_specimen(obs) if obs.specimen
      naming = obs.namings.create(name: @name)
      obs.change_vote(naming, @vote, user)
      obs.log(:log_observation_created_at) if @log
    end

    def create_specimen(obs)
      @herbarium ||= user.personal_herbarium || Herbarium.create!(
        name: user.personal_herbarium_name,
        personal_user: user
      )
      obs.specimens << Specimen.create!(
        herbarium: @herbarium,
        when: Time.zone.now,
        user: user,
        herbarium_label: @herbarium_label ||
                         Herbarium.default_specimen_label(
                           @name.text_name, @specimen_id || obs.id
                         )
      )
    end

    def build_setter
      lat = parse_latitude(:set_latitude)
      long = parse_longitude(:set_longitude)
      alt = parse_altitude(:set_altitude)
      if !lat != !long
        errors << LatLongMustBothBeSet.new
        lat = long = nil
      end

      thumbnail = parse_image(:set_thumbnail)
      add_images = parse_images(:add_images) || []
      remove_images = parse_images(:remove_images) || []
      if thumbnail && !add_images.include?(thumbnail)
        add_images.unshift(thumbnail)
      end

      add_projects = parse_projects(:add_projects) || []
      remove_projects = parse_projects(:remove_projects) || []

      add_species_lists = parse_species_lists(:add_species_lists) || []
      remove_species_lists = parse_species_lists(:remove_species_lists) || []

      params = {
        when: parse_date(:set_date),
        notes: parse_string(:set_notes),
        place_name: parse_place_name(:set_location, limit: 1024),
        lat: lat,
        long: long,
        alt: alt,
        specimen: parse_boolean(:set_has_specimen),
        is_collection_location: parse_boolean(:set_is_collection_location),
        thumb_image: thumbnail
      }
      params.remove_nils!

      if params.empty? &&
         add_images.empty? &&
         remove_images.empty? &&
         add_projects.empty? &&
         remove_projects.empty? &&
         add_species_lists.empty? &&
         remove_species_lists.empty?
        raise MissingSetParameters.new
      end

      lambda do |obj|
        must_have_edit_permission!(obj)
        obj.update!(params)
        obj.images.push(*add_images) if add_images.any?
        obj.images.delete(*remove_images) if remove_images.any?
        obj.projects.push(*add_projects) if add_projects.any?
        obj.projects.delete(*remove_projects) if remove_projects.any?
        obj.species_lists.push(*add_species_lists) if add_species_lists.any?
<<<<<<< 080ed26c8da92369d6c5e550d231493509e3efef
        return unless remove_species_lists.any?
        obj.species_lists.delete(*remove_species_lists)
=======
        if remove_species_lists.any?
          obj.species_lists.delete(*remove_species_lists)
        end
>>>>>>> Simple Rubcopping in API files touched in this branch
      end
    end
  end
end
