# encoding: utf-8

class API
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
      { :namings => :name },
      :user,
    ]

    self.low_detail_includes = [
      :location,
      :name,
      :user,
    ]

    def query_params
      {
        :where          => sql_id_condition,
        :created        => parse_time_ranges(:created),
        :modified       => parse_time_ranges(:modified),
        :date           => parse_date_ranges(:date),
        :users          => parse_users(:user),
        :names          => parse_names(:name),
        :synonym_names  => parse_names(:synonyms_of),
        :children_names => parse_names(:children_of),
        :locations      => parse_locations(:locations),
        :species_lists  => parse_species_lists(:species_lists),
        :confidence     => parse_float_range(:confidence),
        :is_col_loc     => parse_boolean(:is_collection_location),
        :has_specimen   => parse_boolean(:has_specimen),
        :has_location   => parse_boolean(:has_location),
        :has_notes      => parse_boolean(:has_notes),
        :has_name       => parse_boolean(:has_name),
        :has_images     => parse_boolean(:has_images),
        :has_votes      => parse_boolean(:has_votes),
        :has_comments   => parse_boolean(:has_comments, :limit => true),
        :notes_has      => parse_string(:notes_has),
        :comments_has   => parse_string(:comments_has),
      }
    end

    def create_params
      @name = parse_name(:name)
      @vote = parse_float(:vote, :default => Vote.maximum_vote)

      loc = parse_place_name(:location, :limit => 1024)
      lat = parse_latitude(:latitude)
      long = parse_longitude(:longitude)
      alt = parse_altitude(:altitude)
      if !lat != !long
        errors << LatLongMustBothBeSet.new
        lat = long = nil
      end
      if !lat && !loc
        errors << MustSupplyLocationOrGPS.new
      end
      loc ||= :UNKNOWN.l

      images = parse_images(:images, :default => [])
      thumbnail = parse_image(:thumbnail, :default => images.first)
      images.unshift(thumbnail) unless images.include?(thumbnail)

      {
        :when          => parse_date(:date, :default => Time.now),
        :notes         => parse_string(:notes, :default => ''),
        :place_name    => loc,
        :lat           => lat,
        :long          => long,
        :alt           => alt,
        :specimen      => parse_boolean(:has_specimen, :default => false),
        :is_collection_location => parse_boolean(:is_collection_location, :default => true),
        :thumb_image   => thumbnail,
        :images        => images,
        :projects      => parse_projects(:projects, :default => [], :must_be_member => true),
        :species_lists => parse_species_lists(:species_lists, :default => [], :must_have_edit_permission => true),
      }
    end

    def validate_create_params!(params)
    end

    def after_create(obs)
      unless @name.blank?
        naming = obs.namings.create(:name => @name)
        obs.change_vote(naming, @vote, user)
      end
      obs.log(:log_observation_created)
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
      if thumbnail and !add_images.include?(thumbnail)
        add_images.unshift(thumbnail)
      end

      add_projects = parse_projects(:add_projects) || []
      remove_projects = parse_projects(:remove_projects) || []

      add_species_lists = parse_species_lists(:add_species_lists) || []
      remove_species_lists = parse_species_lists(:remove_species_lists) || []

      params = {
        :when        => parse_date(:set_date),
        :notes       => parse_string(:set_notes),
        :place_name  => parse_place_name(:set_location, :limit => 1024),
        :lat         => lat,
        :long        => long,
        :alt         => alt,
        :specimen    => parse_boolean(:set_has_specimen),
        :is_collection_location => parse_boolean(:set_is_collection_location),
        :thumb_image => thumbnail,
      }
      params.remove_nils!

      if params.empty? and
         add_images.empty? and
         remove_images.empty? and
         add_projects.empty? and
         remove_projects.empty? and
         add_species_lists.empty? and
         remove_species_lists.empty?
        raise MissingSetParameters.new
      end

      lambda do |obj|
        must_have_edit_permission!(obj)
        obj.update_attributes!(params)
        obj.images.push(*add_images) if add_images.any?
        obj.images.delete(*remove_images) if remove_images.any?
        obj.projects.push(*add_projects) if add_projects.any?
        obj.projects.delete(*remove_projects) if remove_projects.any?
        obj.species_lists.push(*add_species_lists) if add_species_lists.any?
        obj.species_lists.delete(*remove_species_lists) if remove_species_lists.any?
      end
    end
  end
end
