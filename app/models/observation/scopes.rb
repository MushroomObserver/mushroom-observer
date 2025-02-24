# frozen_string_literal: true

module Observation::Scopes # rubocop:disable Metrics/ModuleLength
  # This is using Concern so we can define the scopes in this included module.
  extend ActiveSupport::Concern

  # NOTE: To improve Coveralls display, avoid one-line stabby lambda scopes.
  # Two line stabby lambdas are OK, it's just the declaration line that will
  # always show as covered.
  included do # rubocop:disable Metrics/BlockLength
    # default ordering for index queries
    scope :index_order,
          -> { order(when: :desc, id: :desc) }
    # overwrite the one in abstract_model, because we have it cached on a column
    scope :order_by_rss_log, lambda {
      where.not(rss_log: nil).reorder(log_updated_at: :desc, id: :desc).distinct
    }
    # The order used on the home page
    scope :by_activity,
          -> { order_by_rss_log }

    # Extra timestamp scopes for when Observation found:
    scope :found_on, lambda { |ymd_string|
      where(arel_table[:when].format("%Y-%m-%d").eq(ymd_string))
    }
    scope :found_after, lambda { |ymd_string|
      where(arel_table[:when].format("%Y-%m-%d") >= ymd_string)
    }
    scope :found_before, lambda { |ymd_string|
      where(arel_table[:when].format("%Y-%m-%d") <= ymd_string)
    }
    scope :found_between, lambda { |early, late|
      where(arel_table[:when].format("%Y-%m-%d") >= early).
        where(arel_table[:when].format("%Y-%m-%d") <= late)
    }

    scope :is_collection_location, lambda { |bool = true|
      if bool.to_s.to_boolean == true
        where(is_collection_location: true)
      else
        not_collection_location
      end
    }
    scope :not_collection_location,
          -> { where(is_collection_location: false) }

    scope :has_images, lambda { |bool = true|
      if bool.to_s.to_boolean == true
        where.not(thumb_image: nil)
      else
        has_no_images
      end
    }
    scope :has_no_images,
          -> { where(thumb_image: nil) }

    scope :has_notes, lambda { |bool = true|
      if bool.to_s.to_boolean == true
        where.not(notes: no_notes)
      else
        has_no_notes
      end
    }
    scope :has_no_notes,
          -> { where(notes: no_notes) }
    scope :notes_has,
          ->(phrase) { search_columns(Observation[:notes], phrase) }

    scope :has_notes_field,
          ->(field) { where(Observation[:notes].matches("%:#{field}:%")) }
    scope :has_notes_fields, lambda { |fields|
      return if fields.empty?

      fields.map! { |field| notes_field_presence_condition(field) }
      conditions = fields.shift
      fields.each { |field| conditions = conditions.or(field) }
      where(conditions)
    }

    # Observation SEARCHABLE_FIELDS :text_name, :where and :notes (currently)
    # NOTE: Must search Name[:search_name], not ideal
    scope :search_content, lambda { |phrase|
      ids = name_search_name_observation_ids(phrase)
      ids += search_columns(Observation.searchable_columns, phrase).map(&:id)
      where(id: ids).distinct
    }
    # The "advanced search" scope for "content". Unexpectedly, merge/or is
    # faster than concatting the Obs and Comment columns together.
    scope :advanced_search, lambda { |phrase|
      comments = Observation.comments_has(phrase).map(&:id)
      notes_has(phrase).distinct.
        or(Observation.where(id: comments).distinct)
    }
    # Checks Name[:search_name], which includes the author
    # (unlike Observation[:text_name]) and is not cached on the obs
    scope :pattern_search, lambda { |phrase|
      ids = name_search_name_observation_ids(phrase)
      ids += search_columns(Observation[:where], phrase).map(&:id)
      where(id: ids).distinct
    }
    # More comprehensive search of Observation fields + Name.search_name,
    # (plus comments ?).
    # scope :search_content_and_associations, lambda { |phrase|
    #   ids = Name.search_name_has(phrase).
    #         includes(:observations).map(&:observations).flatten.uniq
    #   ids += Observation.search_content_except_notes(phrase).map(&:id)
    #   ids += Observation.comments_has(phrase).map(&:id)
    #   where(id: ids).distinct
    # }
    def self.name_search_name_observation_ids(phrase)
      Name.search_name_has(phrase).
        includes(:observations).map(&:observations).flatten.uniq
    end

    scope :of_lichens, lambda { |bool = true|
      if bool.to_s.to_boolean == true
        where(Observation[:lifeform].matches("%lichen%"))
      else
        not_lichens
      end
    }
    scope :not_lichens,
          -> { where(Observation[:lifeform].does_not_match("% lichen %")) }

    scope :has_name, lambda { |bool = true|
      if bool.to_s.to_boolean == true
        where.not(name: Name.unknown)
      else
        has_no_name
      end
    }
    scope :has_no_name,
          -> { where(name: Name.unknown) }

    # Filters for confidence on vote_cache scale -3.0..3.0
    # To translate percentage to vote_cache: (val.to_f / (100 / 3))
    scope :confidence, lambda { |min, max = nil|
      min, max = min if min.is_a?(Array) && min.size == 2
      if max.nil? || max == min # max may be 0
        where(Observation[:vote_cache].gteq(min))
      else
        where(Observation[:vote_cache].in(min..max))
      end
    }
    # Use this definition when running script to populate the column:
    # scope :needs_naming, lambda {
    #   with_name_above_genus.or(has_no_confident_name)
    # }
    scope :needs_naming,
          -> { where(needs_naming: true) }
    scope :with_name_above_genus,
          -> { where(name_id: Name.with_rank_above_genus) }
    scope :has_no_confident_name,
          -> { where(vote_cache: ..0) }
    scope :with_name_correctly_spelled, lambda { |bool = true|
      if bool.to_s.to_boolean == true
        joins({ namings: :name }).
          where(names: { correct_spelling: nil }).distinct
      else
        with_misspelled_name
      end
    }
    scope :with_misspelled_name, lambda {
      joins({ namings: :name }).
        where.not(names: { correct_spelling: nil }).distinct
    }

    scope :with_vote_by_user, lambda { |user|
      user_id = user.is_a?(Integer) ? user : user&.id
      joins(:votes).where(votes: { user_id: user_id })
    }
    scope :without_vote_by_user, lambda { |user|
      user_id = user.is_a?(Integer) ? user : user&.id
      where.not(id: Vote.where(user_id: user_id))
    }
    scope :reviewed_by_user, lambda { |user|
      user_id = user.is_a?(Integer) ? user : user&.id
      joins(:observation_views).
        where(observation_views: { user_id: user_id, reviewed: 1 })
    }
    scope :not_reviewed_by_user, lambda { |user|
      user_id = user.is_a?(Integer) ? user : user&.id
      where.not(id: ObservationView.where(user_id: user_id, reviewed: 1).
                    select(:observation_id))
    }
    scope :needs_naming_and_not_reviewed_by_user, lambda { |user|
      needs_naming.not_reviewed_by_user(user).distinct
    }
    # Higher taxa: returns narrowed-down group of id'd obs,
    # in higher taxa under the given taxon
    # scope :needs_naming_by_taxon, lambda { |user, name|
    #   name_plus_subtaxa = Name.include_subtaxa_of(name)
    #   subtaxa_above_genus = name_plus_subtaxa.with_rank_above_genus
    #   lower_subtaxa = name_plus_subtaxa.with_rank_at_or_below_genus

    #   where(name_id: subtaxa_above_genus).or(
    #     Observation.where(name_id: lower_subtaxa).and(
    #       Observation.where(vote_cache: ..0)
    #     )
    #   ).without_vote_by_user(user).not_reviewed_by_user(user).distinct
    # }

    # scope :of_names(name, **args)
    #
    # Accepts either a Name instance, a string, or an id as the first argument.
    #  Other args:
    #  - include_synonyms: boolean
    #  - include_subtaxa: boolean
    #  - include_all_name_proposals: boolean
    #  - of_look_alikes: boolean
    #
    scope :of_names, lambda { |names, **args|
      # First, lookup names, plus synonyms and subtaxa if requested
      lookup_args = args.slice(:include_synonyms, :include_subtaxa)
      name_ids = Lookup::Names.new(names, **lookup_args).ids

      # Query, with possible join to Naming. Mutually exclusive options:
      if args[:include_all_name_proposals]
        joins(:namings).where(namings: { name_id: name_ids })
      elsif args[:of_look_alikes]
        joins(:namings).where(namings: { name_id: name_ids }).
          where.not(name: name_ids)
      else
        where(name_id: name_ids)
      end
    }
    scope :of_names_like,
          ->(name) { where(name: Name.text_name_has(name)) }
    scope :in_clade, lambda { |val|
      # parse_name_and_rank defined below
      text_name, rank = parse_name_and_rank(val)

      if Name.ranks_above_genus.include?(rank)
        where(text_name: text_name).or(
          where(Observation[:classification].
          matches("%#{rank}: _#{text_name}_%"))
        )
      else
        where(text_name: text_name).or(
          where(Observation[:text_name].matches("#{text_name} %"))
        )
      end
    }

    # used for preloading values in the create obs form. call with `.last`
    scope :recent_by_user, lambda { |user|
      includes(:location, :projects, :species_lists).
        where(user_id: user.id).reorder(:created_at)
    }
    scope :mappable,
          -> { where.not(location: nil).or(where.not(lat: nil)) }
    scope :unmappable,
          -> { where(location: nil).and(where(lat: nil)) }
    scope :has_location,
          -> { where.not(location: nil) }
    scope :has_no_location,
          -> { where(location: nil) }
    scope :has_geolocation,
          -> { where.not(lat: nil) }
    scope :has_no_geolocation,
          -> { where(lat: nil) }
    scope :has_public_lat_lng, lambda { |bool = true|
      if bool.to_s.to_boolean == true
        where(gps_hidden: false).where.not(lat: nil)
      else
        has_no_public_lat_lng
      end
    }
    scope :has_no_public_lat_lng,
          -> { where(gps_hidden: true).or(where(lat: nil)) }

    scope :at_locations, lambda { |locations|
      location_ids = Lookup::Locations.new(locations).ids
      where(location: location_ids).distinct
    }
    scope :in_regions, lambda { |place_names|
      place_names = [place_names].flatten
      if place_names.length > 1
        starting = in_region(place_names.shift)
        place_names.reduce(starting) do |result, place_name|
          result.or(Observation.in_region(place_name))
        end
      else
        in_region(place_names.first)
      end
    }
    scope :in_region, lambda { |place_name|
      region = Location.reverse_name_if_necessary(place_name)

      if Location.understood_continent?(region)
        countries = Location.countries_in_continent(region)
        where(Observation[:where] =~ ", (#{countries.join("|")})$")
      else
        where(Observation[:where].matches("%#{region}"))
      end
    }
    # Pass Box kwargs (:north, :south, :east, :west), any order.
    # By default this scope selects only obs either with lat/lng or with useful
    # locations, where we have cached the location center point on the obs.
    # As a utility convenience, you can pass `vague: true` to include all obs,
    # including those with vague (huge) locations.
    scope :in_box, lambda { |**args|
      box = Mappable::Box.new(**args.except(:vague))
      return none unless box.valid?

      if box.straddles_180_deg?
        in_box_over_dateline(**args)
      else
        in_box_regular(**args)
      end
    }
    # mostly a helper for in_box
    scope :in_box_over_dateline, lambda { |**args|
      include_vague_locations = args[:vague] || false
      box = Mappable::Box.new(**args.except(:mappable))
      return none unless box.valid?

      if include_vague_locations
        # this join is necessary for the `or` condition, which requires it
        left_outer_joins(:location).gps_in_box_over_dateline(box).
          or(Observation.associated_location_center_in_box_over_dateline(box))
      else
        gps_in_box_over_dateline(box).
          or(Observation.cached_location_center_in_box_over_dateline(box))
      end
    }
    # In these the box.east edge is in the w hemisphere, -180..
    #      and the box.west edge is in the e hemisphere, ..180
    scope :gps_in_box_over_dateline, lambda { |box|
      where(
        (Observation[:lat] >= box.south).
        and(Observation[:lat] <= box.north).
        and(Observation[:lng] >= box.west).
        or(Observation[:lng] <= box.east)
      )
    }
    scope :cached_location_center_in_box_over_dateline, lambda { |box|
      where(
        Observation[:lat].eq(nil).
        and(Observation[:location_lat] >= box.south).
        and(Observation[:location_lat] <= box.north).
        and(Observation[:location_lng] >= box.west).
        or(Observation[:location_lng] <= box.east)
      )
    }
    scope :associated_location_center_in_box_over_dateline, lambda { |box|
      left_outer_joins(:location).
        where(
          Observation[:lat].eq(nil).
          and(Location[:center_lat] >= box.south).
          and(Location[:center_lat] <= box.north).
          and(Location[:center_lng] >= box.west).
          or(Location[:center_lng] <= box.east)
        )
    }
    # mostly a helper for in_box
    scope :in_box_regular, lambda { |**args|
      include_vague_locations = args[:vague] || false
      box = Mappable::Box.new(**args.except(:mappable))
      return none unless box.valid?

      if include_vague_locations
        # this join is necessary for the `or` condition, which requires it
        left_outer_joins(:location).gps_in_box(box).
          or(Observation.associated_location_center_in_box(box))
      else
        gps_in_box(box).or(Observation.cached_location_center_in_box(box))
      end
    }
    scope :gps_in_box, lambda { |box|
      where(
        (Observation[:lat] >= box.south).
        and(Observation[:lat] <= box.north).
        and(Observation[:lng] <= box.east).
        and(Observation[:lng] >= box.west)
      )
    }
    scope :cached_location_center_in_box, lambda { |box|
      # odd! AR will toss entire condition if below order is west, east
      where(
        Observation[:lat].eq(nil).
        and(Observation[:location_lat] >= box.south).
        and(Observation[:location_lat] <= box.north).
        and(Observation[:location_lng] <= box.east).
        and(Observation[:location_lng] >= box.west)
      )
    }
    scope :associated_location_center_in_box, lambda { |box|
      left_outer_joins(:location).
        where(
          Observation[:lat].eq(nil).
          and(Location[:center_lat] >= box.south).
          and(Location[:center_lat] <= box.north).
          and(Location[:center_lng] <= box.east).
          and(Location[:center_lng] >= box.west)
        )
    }
    # Pass kwargs (:north, :south, :east, :west), any order
    scope :not_in_box, lambda { |**args|
      box = Mappable::Box.new(**args.except(:mappable))
      return Observation.all unless box.valid?

      # should be in_box(**args).invert_where
      if box.straddles_180_deg?
        not_in_box_over_dateline(**args)
      else
        not_in_box_regular(**args)
      end
    }
    # helper for not_in_box
    scope :not_in_box_over_dateline, lambda { |**args|
      box = Mappable::Box.new(**args.except(:mappable))
      return Observation.all unless box.valid?

      where(
        Observation[:lat].eq(nil).
        or(Observation[:lat] < box.south).or(Observation[:lat] > box.north).
        or((Observation[:lng] < box.west).and(Observation[:lng] > box.east))
      )
    }
    # helper for not_in_box
    scope :not_in_box_regular, lambda { |**args|
      box = Mappable::Box.new(**args.except(:mappable))
      return Observation.all unless box.valid?

      where(
        Observation[:lat].eq(nil).
        or(Observation[:lat] < box.south).or(Observation[:lat] > box.north).
        or(Observation[:lng] < box.west).or(Observation[:lng] > box.east)
      )
    }
    scope :in_box_of_max_area, lambda { |**args|
      args[:area] ||= MO.obs_location_max_area

      joins(:location).where(Location[:box_area].lteq(args[:area])).distinct
    }
    scope :in_box_gt_max_area, lambda { |**args|
      args[:area] ||= MO.obs_location_max_area

      joins(:location).where(Location[:box_area].gt(args[:area])).distinct
    }

    scope :has_comments, lambda { |bool = true|
      if bool.to_s.to_boolean == true
        joins(:comments).distinct
      else
        has_no_comments
      end
    }
    scope :has_no_comments,
          -> { where.not(id: Observation.has_comments) }
    scope :comments_has, lambda { |phrase|
      joins(:comments).merge(Comment.search_content(phrase)).distinct
    }

    scope :has_specimen, lambda { |bool = true|
      if bool.to_s.to_boolean == true
        where(specimen: true)
      else
        has_no_specimen
      end
    }
    scope :has_no_specimen,
          -> { where(specimen: false) }

    scope :has_sequences, lambda { |bool = true|
      if bool.to_s.to_boolean == true
        joins(:sequences).distinct
      else
        has_no_sequences
      end
    }
    # much faster than `missing(:sequences)` which uses left outer join.
    scope :has_no_sequences,
          -> { where.not(id: has_sequences) }

    # For activerecord subqueries, no need to pre-map the primary key (id)
    # but Lookup has to return something. Ids are cheapest.
    scope :for_projects, lambda { |projects|
      project_ids = Lookup::Projects.new(projects).ids
      joins(:project_observations).
        where(project_observations: { project: project_ids }).distinct
    }
    scope :on_species_lists, lambda { |species_lists|
      spl_ids = Lookup::SpeciesLists.new(species_lists).ids
      joins(:species_list_observations).
        where(species_list_observations: { species_list: spl_ids }).distinct
    }
    scope :on_projects_species_lists, lambda { |projects|
      project_ids = Lookup::Projects.new(projects).ids
      joins(species_lists: :project_species_lists).
        where(project_species_lists: { project: project_ids }).distinct
    }
    scope :for_field_slips, lambda { |codes|
      fs_ids = Lookup::FieldSlips.new(codes).ids
      joins(:field_slips).where(field_slips: { id: fs_ids }).distinct
    }
    scope :for_herbarium_records, lambda { |records|
      hr_ids = Lookup::HerbariumRecords.new(records).ids
      joins(:observation_herbarium_records).
        where(observation_herbarium_records: { herbarium_record: hr_ids }).
        distinct
    }
    scope :in_herbaria, lambda { |herbaria|
      h_ids = Lookup::Herbaria.new(herbaria).ids
      joins(observation_herbarium_records: :herbarium_record).
        where(herbarium_records: { herbarium: h_ids }).distinct
    }
    scope :herbarium_record_notes_has, lambda { |phrase|
      joins(:herbarium_records).
        search_columns(HerbariumRecord[:notes], phrase).distinct
    }

    scope :show_includes, lambda {
      strict_loading.includes(
        :collection_numbers,
        :field_slips,
        { comments: :user },
        { external_links: { external_site: { project: :user_group } } },
        { herbarium_records: [{ herbarium: :curators }, :user] },
        { images: [:image_votes, :license, :projects, :user] },
        { interests: :user },
        :location,
        { name: { synonym: :names } },
        { namings: [:name, :user, { votes: [:observation, :user] }] },
        { projects: :admin_group },
        :rss_log,
        :sequences,
        { species_lists: [:projects, :user] },
        :thumb_image,
        :user
      )
    }
    scope :not_logged_in_show_includes, lambda {
      strict_loading.includes(
        { comments: :user },
        { images: [:image_votes, :license, :user] },
        :location,
        { name: { synonym: :names } },
        { namings: [:name, :user, { votes: [:observation, :user] }] },
        :projects,
        :thumb_image,
        :user
      )
    }
    scope :naming_includes, lambda {
      includes(
        { herbarium_records: [:herbarium] }, # in case naming is "Imageless"
        :location, # ugh. worth it because of cache_content_filter_data
        :name,
        # Observation#find_matches complains synonym is not eager-loaded. TBD
        { namings: [{ name: { synonym: :names } }, :user,
                    { votes: [:observation, :user] }] },
        :species_lists, # in case naming is "Imageless"
        :user
      )
    }
    scope :edit_includes, lambda {
      strict_loading.includes(
        :collection_numbers,
        :field_slips,
        { external_links: { external_site: { project: :user_group } } },
        { herbarium_records: [{ herbarium: :curators }, :user] },
        { images: [:image_votes, :license, :projects, :user] },
        { interests: :user },
        :location,
        { name: { synonym: :names } },
        { projects: :admin_group },
        :rss_log,
        :sequences,
        { species_lists: [:projects, :user] },
        :thumb_image,
        :user
      )
    }
  end

  module ClassMethods
    # class methods here, `self` included
    def parse_name_and_rank(val)
      return [val.text_name, val.rank] if val.is_a?(Name)

      name = Name.best_match(val)
      return [name.text_name, name.rank] if name

      [val, Name.guess_rank(val) || "Genus"]
    end

    def notes_field_presence_condition(field)
      field = field.dup
      pat = if field.gsub!(/(["\\])/) { '\\\1' }
              "\":#{field}:\""
            else
              ":#{field}:"
            end
      Observation[:notes].matches("%#{pat}%")
    end
  end
end
