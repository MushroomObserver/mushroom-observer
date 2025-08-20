# frozen_string_literal: true

module Observation::Scopes # rubocop:disable Metrics/ModuleLength
  # This is using Concern so we can define the scopes in this included module.
  extend ActiveSupport::Concern

  # NOTE: To improve Coveralls display, avoid one-line stabby lambda scopes.
  # Two line stabby lambdas are OK, it's just the declaration line that will
  # always show as covered.
  included do
    # default ordering for index queries
    scope :order_by_default,
          -> { order_by(::Query::Observations.default_order) }
    # The order used on the home page
    scope :by_activity,
          -> { order_by(:rss_log) }

    # Extra timestamp scopes for when Observation found.
    # These are mostly aliases for `date` scopes.
    scope :found_on, lambda { |ymd_string|
      on_date(ymd_string)
    }
    scope :found_after, lambda { |ymd_string|
      date(ymd_string)
    }
    scope :found_before, lambda { |ymd_string|
      date_before(ymd_string)
    }
    scope :found_between, lambda { |early, late|
      date(early, late)
    }

    # NOTE: `Observation.no_notes` evaluates to '--- {}\n' because it's to_yaml.
    # This is unlike other models with notes. This scope could be simpler:
    #       ->(bool = true) { not_blank_condition(Observation[:notes], bool:) }
    scope :has_notes, lambda { |bool = true|
      if bool.to_s.to_boolean == true
        where.not(notes: no_notes)
      else
        where(notes: no_notes)
      end
    }
    scope :notes_has,
          ->(phrase) { search_columns(Observation[:notes], phrase) }

    scope :has_notes_field,
          ->(field) { where(Observation[:notes].matches("%:#{field}:%")) }
    scope :has_notes_fields, lambda { |fields|
      return if (fields = [fields].flatten).empty?

      fields.map! { |field| notes_field_presence_condition(field) }
      conditions = fields.shift
      fields.each { |field| conditions = conditions.or(field) }
      where(conditions)
    }

    # FOR FUTURE REFERENCE
    # The "advanced search" scope for "content". Unexpectedly, merge/or is
    # faster than concatting the Obs and Comment columns together.
    # scope :advanced_search, lambda { |phrase|
    #   comments = Observation.comments_has(phrase).map(&:id)
    #   notes_has(phrase).distinct.
    #     or(Observation.where(id: comments).distinct)
    # }
    # Checks Name[:search_name], which includes the author
    # (unlike Observation[:text_name]) and is not cached on the obs
    scope :pattern, lambda { |phrase|
      joins(:name).distinct.
        search_columns(Observation[:where] + Name[:search_name], phrase)
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

    # Query parses "yes" and "no", "on" and "off" to boolean. nil ignored.
    scope :lichen, lambda { |bool = true|
      case bool
      when true
        where(Observation[:lifeform].matches("%lichen%"))
      when false
        where(Observation[:lifeform].does_not_match("% lichen %"))
      end
    }

    # Filters for confidence on vote_cache scale -3.0..3.0
    # To translate percentage to vote_cache: (val.to_f / (100 / 3))
    scope :confidence, lambda { |min, max = nil|
      min, max = min if min.is_a?(Array)
      if max.nil? || max == min # max may be 0
        where(Observation[:vote_cache].gteq(min))
      else
        where(Observation[:vote_cache].in(min..max))
      end
    }
    scope :needs_naming, lambda { |user|
      needs_naming_generally.not_reviewed_by_user(user).distinct
    }
    scope :needs_naming_generally,
          ->(bool = true) { where(needs_naming: bool) }
    # Use this definition when running script to populate the column:
    # scope :has_no_confident_species_name, lambda {
    #   with_name_above_genus.or(has_no_confident_name)
    # }
    scope :with_name_above_genus,
          -> { where(name_id: Name.with_rank_above_genus) }
    scope :has_no_confident_name,
          -> { where(vote_cache: ..0) }
    scope :with_vote_by_user, lambda { |user|
      user_id = user.is_a?(Integer) ? user : user&.id
      joins(:votes).where(votes: { user_id: user_id })
    }
    scope :without_vote_by_user, lambda { |user|
      where.not(id: Observation.with_vote_by_user(user))
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
    # Higher taxa: returns narrowed-down group of id'd obs,
    # in higher taxa under the given taxon
    # scope :needs_naming_by_taxon, lambda { |user, name|
    #   name_plus_subtaxa = Name.names(lookup: name, include_subtaxa: true)
    #   subtaxa_above_genus = name_plus_subtaxa.with_rank_above_genus
    #   lower_subtaxa = name_plus_subtaxa.with_rank_at_or_below_genus

    #   where(name_id: subtaxa_above_genus).or(
    #     Observation.where(name_id: lower_subtaxa).and(
    #       Observation.where(vote_cache: ..0)
    #     )
    #   ).without_vote_by_user(user).not_reviewed_by_user(user).distinct
    # }

    scope :has_name, lambda { |bool = true|
      if bool.to_s.to_boolean == true
        where.not(name: Name.unknown)
      else
        where(name: Name.unknown)
      end
    }
    # Accepts either a Name instance, a string, or an id as the first argument.
    #  Other args:
    #  - include_synonyms: boolean
    #  - include_subtaxa: boolean
    #  - include_immediate_subtaxa: boolean
    #  - exclude_original_names: boolean
    #  - include_all_name_proposals: boolean
    #  - exclude_consensus: boolean
    #
    scope :names, lambda { |lookup:, **args|
      if args[:include_all_name_proposals] == false &&
         args[:exclude_consensus] == true
        return none
      end

      # Next, lookup names, plus synonyms and subtaxa if requested
      lookup_args = args.slice(:include_synonyms,
                               :include_misspellings,
                               :include_subtaxa,
                               :include_immediate_subtaxa,
                               :exclude_original_names)
      name_ids = Lookup::Names.new(lookup, **lookup_args).ids
      return none unless name_ids

      scope = all
      # Query, with possible join to Naming. Mutually exclusive options:
      if args[:include_all_name_proposals] || args[:exclude_consensus]
        scope = scope.joins(:namings).where(namings: { name_id: name_ids })
        scope = scope.where.not(name_id: name_ids) if args[:exclude_consensus]
      else
        scope = scope.where(name_id: name_ids)
      end
      scope.distinct
    }
    scope :names_like,
          ->(name) { where(name: Name.text_name_has(name)) }

    # This should really be clades/clade, but changing user prefs/filters and
    # autocompleters is very involved, requires migration and script.
    scope :clade, lambda { |clades|
      clades = [clades].flatten
      clades.map! { |val| one_clade(val) }
      or_clause(*clades).distinct
    }
    scope :one_clade, lambda { |val|
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

    scope :is_collection_location,
          ->(bool = true) { where(is_collection_location: bool) }
    scope :has_public_lat_lng, lambda { |bool = true|
      if bool.to_s.to_boolean == true
        where(gps_hidden: false).where.not(lat: nil)
      else
        where(gps_hidden: true).or(where(lat: nil))
      end
    }

    scope :has_location, lambda { |bool = true|
      presence_condition(Observation[:location_id], bool:)
    }
    scope :location_undefined, lambda { |_bool = true|
      has_location(false).where.not(where: nil).group(:where).
        order(Observation[:where].count.desc, Observation[:id].desc)
    }
    scope :mappable,
          -> { where.not(location: nil).or(where.not(lat: nil)) }
    scope :unmappable,
          -> { where(location: nil).and(where(lat: nil)) }
    scope :has_geolocation,
          ->(bool = true) { presence_condition(Observation[:lat], bool:) }

    # This should really be regions/region, but changing user prefs/filters and
    # autocompleters is very involved, requires migration and script.
    scope :region, lambda { |place_names|
      place_names = [place_names].flatten
      place_names.map! { |val| one_region(val) }
      or_clause(*place_names).distinct
    }
    scope :one_region, lambda { |place_name|
      region = Location.reverse_name_if_necessary(place_name)

      if Location.understood_continent?(region)
        countries = Location.countries_in_continent(region)
        where(Observation[:where] =~ ", (#{countries.join("|")})$")
      else
        where(Observation[:where].matches("%#{region}"))
      end
    }
    scope :locations, lambda { |locations|
      locs = ::Lookup::Locations.new(locations).instances
      in_boxes = locs.map! { |location| in_box(**location.bounding_box) }
      or_clause(*in_boxes).distinct
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
      box = Mappable::Box.new(**args.except(:vague))
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
      ).distinct
    }
    scope :cached_location_center_in_box_over_dateline, lambda { |box|
      where(
        Observation[:lat].eq(nil).
        and(Observation[:location_lat] >= box.south).
        and(Observation[:location_lat] <= box.north).
        and(Observation[:location_lng] >= box.west).
        or(Observation[:location_lng] <= box.east)
      ).distinct
    }
    scope :associated_location_center_in_box_over_dateline, lambda { |box|
      left_outer_joins(:location).
        where(
          Observation[:lat].eq(nil).
          and(Location[:center_lat] >= box.south).
          and(Location[:center_lat] <= box.north).
          and(Location[:center_lng] >= box.west).
          or(Location[:center_lng] <= box.east)
        ).distinct
    }
    # mostly a helper for in_box
    scope :in_box_regular, lambda { |**args|
      include_vague_locations = args[:vague] || false
      box = Mappable::Box.new(**args.except(:vague))
      return none unless box.valid?

      if include_vague_locations
        # this join is necessary for the `or` condition, which requires it
        left_outer_joins(:location).gps_in_box(box).
          or(Observation.associated_location_center_in_box(box))
      else
        gps_in_box(box).or(
          Observation.cached_location_center_in_box(box)
        )
      end
    }
    scope :gps_in_box, lambda { |box|
      where(
        (Observation[:lat] >= box.south).
        and(Observation[:lat] <= box.north).
        and(Observation[:lng] <= box.east).
        and(Observation[:lng] >= box.west)
      ).distinct
    }
    scope :cached_location_center_in_box, lambda { |box|
      # odd! AR will toss entire condition if below order is west, east
      where(
        Observation[:lat].eq(nil).
        and(Observation[:location_lat] >= box.south).
        and(Observation[:location_lat] <= box.north).
        and(Observation[:location_lng] <= box.east).
        and(Observation[:location_lng] >= box.west)
      ).distinct
    }
    scope :associated_location_center_in_box, lambda { |box|
      left_outer_joins(:location).
        where(
          Observation[:lat].eq(nil).
          and(Location[:center_lat] >= box.south).
          and(Location[:center_lat] <= box.north).
          and(Location[:center_lng] <= box.east).
          and(Location[:center_lng] >= box.west)
        ).distinct
    }
    # Pass kwargs (:north, :south, :east, :west), any order
    scope :not_in_box, lambda { |**args|
      box = Mappable::Box.new(**args.except(:vague))
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
      box = Mappable::Box.new(**args.except(:vague))
      return Observation.all unless box.valid?

      where(
        Observation[:lat].eq(nil).
        or(Observation[:lat] < box.south).or(Observation[:lat] > box.north).
        or((Observation[:lng] < box.west).and(Observation[:lng] > box.east))
      )
    }
    # helper for not_in_box
    scope :not_in_box_regular, lambda { |**args|
      box = Mappable::Box.new(**args.except(:vague))
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

    # content filter
    scope :has_images, lambda { |bool = true|
      presence_condition(Observation[:thumb_image_id], bool:)
    }
    # content filter
    scope :has_specimen,
          ->(bool = true) { where(specimen: bool) }

    scope :has_sequences, lambda { |bool = true|
      return all unless bool

      joined_relation_condition(:sequences, bool:)
    }

    # For activerecord subqueries, no need to pre-map the primary key (id)
    # but Lookup has to return something. Ids are cheapest.
    scope :field_slips, lambda { |codes|
      fs_ids = Lookup::FieldSlips.new(codes).ids
      joins(:field_slips).where(field_slips: { id: fs_ids }).distinct
    }
    scope :herbaria, lambda { |herbaria|
      h_ids = Lookup::Herbaria.new(herbaria).ids
      joins(observation_herbarium_records: :herbarium_record).
        where(herbarium_records: { herbarium: h_ids }).distinct
    }
    scope :herbarium_records, lambda { |records|
      hr_ids = Lookup::HerbariumRecords.new(records).ids
      joins(:observation_herbarium_records).
        where(observation_herbarium_records: { herbarium_record: hr_ids }).
        distinct
    }
    scope :projects, lambda { |projects|
      project_ids = Lookup::Projects.new(projects).ids
      joins(:project_observations).
        where(project_observations: { project: project_ids }).distinct
    }
    scope :project_lists, lambda { |projects|
      project_ids = Lookup::Projects.new(projects).ids
      joins(species_lists: :project_species_lists).
        where(project_species_lists: { project: project_ids }).distinct
    }
    scope :species_lists, lambda { |species_lists|
      spl_ids = Lookup::SpeciesLists.new(species_lists).ids
      joins(:species_list_observations).
        where(species_list_observations: { species_list: spl_ids }).distinct
    }

    scope :image_query, lambda { |hash|
      joins(:images).subquery(:Image, hash)
    }
    scope :location_query, lambda { |hash|
      joins(:location).subquery(:Location, hash)
    }
    scope :name_query, lambda { |hash|
      joins(:name).subquery(:Name, hash)
    }
    scope :sequence_query, lambda { |hash|
      joins(:sequences).subquery(:Sequence, hash)
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
