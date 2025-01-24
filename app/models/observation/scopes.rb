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
    scope :found_between, lambda { |earliest, latest|
      where(arel_table[:when].format("%Y-%m-%d") >= earliest).
        where(arel_table[:when].format("%Y-%m-%d") <= latest)
    }

    # For activerecord subqueries, DON'T pre-map the primary key (id)
    scope :with_name,
          -> { where.not(name: Name.unknown) }
    scope :without_name,
          -> { where(name: Name.unknown) }
    scope :with_name_above_genus,
          -> { where(name_id: Name.with_rank_above_genus) }
    scope :without_confident_name,
          -> { where(vote_cache: ..0) }
    # Use this definition when running script to populate the column:
    # scope :needs_naming, lambda {
    #   with_name_above_genus.or(without_confident_name)
    # }
    scope :needs_naming,
          -> { where(needs_naming: true) }
    scope :with_name_correctly_spelled, lambda {
      joins({ namings: :name }).where(names: { correct_spelling: nil })
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

    # scope :of_name(name, **args)
    #
    # Accepts either a Name instance, a string, or an id as the first argument.
    #  Other args:
    #  - include_synonyms: boolean
    #  - include_subtaxa: boolean
    #  - include_all_name_proposals: boolean
    #  - of_look_alikes: boolean
    #
    scope :of_name, lambda { |name, **args|
      # First, get a name record if string or id submitted
      case name
      when String
        name = Name.find_by(text_name: name)
      when Integer
        name = Name.find_by(id: name)
      end
      return Observation.none unless name.is_a?(Name)

      # Filter args may add to an array of names to collect Observations
      names_array = [name]
      # Maybe add synonyms (Name#synonyms includes original name)
      names_array = name.synonyms if args[:include_synonyms]
      # Keep names_array intact as is; maybe add more to its clone name_ids.
      # (I'm thinking it's easier to pass name ids to the Observation query)
      name_ids = names_array

      # Add subtaxa to name_ids array. Subtaxa of synonyms too, if requested
      # (don't modify the names_array we're iterating over)
      if args[:include_subtaxa]
        names_array.each do |n|
          # |= don't add duplicates
          name_ids |= Name.subtaxa_of(n)
        end
      end

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
    scope :of_name_like,
          ->(name) { where(name: Name.text_name_contains(name)) }
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
    scope :with_location,
          -> { where.not(location: nil) }
    scope :without_location,
          -> { where(location: nil) }
    scope :with_geolocation,
          -> { where.not(lat: nil) }
    scope :without_geolocation,
          -> { where(lat: nil) }
    scope :with_public_geolocation,
          -> { where(gps_hidden: false).where.not(lat: nil) }
    scope :without_public_geolocation,
          -> { where(gps_hidden: true).or(where(lat: nil)) }
    scope :at_location, ->(location) { where(location: location) }
    scope :in_region, lambda { |place_name|
      region = Location.reverse_name_if_necessary(place_name)

      if Location.understood_continent?(region)
        countries = Location.countries_in_continent(region)
        where(Observation[:where] =~ ", (#{countries.join("|")})$")
      else
        where(Observation[:where].matches("%#{region}"))
      end
    }
    # Pass kwargs (:north, :south, :east, :west), any order
    # Pass mappable: false to include all obs, including with vague locations.
    scope :in_box, lambda { |**args|
      args[:mappable] ||= false
      box = Mappable::Box.new(**args.except(:mappable))
      return none unless box.valid?

      if box.straddles_180_deg?
        in_box_straddling_dateline(**args)
      else
        in_box_regular(**args)
      end
    }
    # mostly a helper for in_box
    scope :in_box_straddling_dateline, lambda { |**args|
      args[:mappable] ||= true
      box = Mappable::Box.new(**args.except(:mappable))
      return none unless box.valid?

      where(
        (Observation[:lat] >= box.south).
        and(Observation[:lat] <= box.north).
        and(Observation[:lng] >= box.west).
        or(Observation[:lng] <= box.east)
      ).or(Observation.location_straddling_dateline(**args))
    }
    scope :location_straddling_dateline, lambda { |**args|
      box = Mappable::Box.new(**args.except(:mappable))
      return none unless box.valid?

      if args[:mappable]
        where(
          Observation[:lat].eq(nil).
          and(Observation[:location_lat] >= box.south).
          and(Observation[:location_lat] <= box.north).
          and(Observation[:location_lng] >= box.west).
          or(Observation[:location_lng] <= box.east)
        )
      else
        joins(:location).
          where(
            Observation[:lat].eq(nil).
            and(Location[:center_lat] >= box.south).
            and(Location[:center_lat] <= box.north).
            and(Location[:center_lng] <= box.east).
            and(Location[:center_lng] >= box.west)
          )
      end
    }
    # mostly a helper for in_box
    scope :in_box_regular, lambda { |**args|
      args[:mappable] ||= true
      box = Mappable::Box.new(**args.except(:mappable))
      return none unless box.valid?

      where(
        (Observation[:lat] >= box.south).and(Observation[:lat] <= box.north).
        and(Observation[:lng] >= box.west).and(Observation[:lng] <= box.east)
      ).or(Observation.location_center_in_box(**args))
    }
    scope :location_center_in_box, lambda { |**args|
      box = Mappable::Box.new(**args.except(:mappable))
      return none unless box.valid?

      # odd! will toss entire condition if below order is west, east
      if args[:mappable]
        where(
          Observation[:lat].eq(nil).
          and(Observation[:location_lat] >= box.south).
          and(Observation[:location_lat] <= box.north).
          and(Observation[:location_lng] <= box.east).
          and(Observation[:location_lng] >= box.west)
        )
      else
        joins(:location).
          where(
            Observation[:lat].eq(nil).
            and(Location[:center_lat] >= box.south).
            and(Location[:center_lat] <= box.north).
            and(Location[:center_lng] <= box.east).
            and(Location[:center_lng] >= box.west)
          )
      end
    }
    # Pass kwargs (:north, :south, :east, :west), any order
    scope :not_in_box, lambda { |**args|
      args[:mappable] ||= false
      box = Mappable::Box.new(**args.except(:mappable))
      return Observation.all unless box.valid?

      # should be in_box(**args).invert_where
      if box.straddles_180_deg?
        not_in_box_straddling_dateline(**args)
      else
        not_in_box_regular(**args)
      end
    }
    # helper for not_in_box
    scope :not_in_box_straddling_dateline, lambda { |**args|
      args[:mappable] ||= false
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
      args[:mappable] ||= false
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

      joins(:location).where(Location[:box_area].lteq(args[:area]))
    }
    scope :in_box_gt_max_area, lambda { |**args|
      args[:area] ||= MO.obs_location_max_area

      joins(:location).where(Location[:box_area].gt(args[:area]))
    }

    scope :is_collection_location,
          -> { where(is_collection_location: true) }
    scope :not_collection_location,
          -> { where(is_collection_location: false) }
    scope :with_images,
          -> { where.not(thumb_image: nil) }
    scope :without_images,
          -> { where(thumb_image: nil) }
    scope :with_notes,
          -> { where.not(notes: no_notes) }
    scope :without_notes,
          -> { where(notes: no_notes) }
    scope :with_notes_field,
          ->(field) { where(Observation[:notes].matches("%:#{field}:%")) }
    scope :with_notes_fields, lambda { |fields|
      return if fields.empty?

      fields.map! { |field| notes_field_presence_condition(field) }
      conditions = fields.shift
      fields.each { |field| conditions = conditions.or(field) }
      where(conditions)
    }
    scope :notes_contain,
          ->(phrase) { search_columns(Observation[:notes], phrase) }
    # Searches Observation fields :name, :where and :notes (currently)
    scope :search_content,
          ->(phrase) { search_columns(Observation.searchable_columns, phrase) }
    # This is the "advanced search" scope that joins to :comments. Unexpectedly,
    # merge/or is faster than concatting the Obs and Comment columns together.
    scope :search_content_and_comments, lambda { |phrase|
      joins(:comments).merge(
        Observation.search_columns(Observation[:notes], phrase).
        or(Comment.search_content(phrase))
      )
    }
    scope :with_specimen,
          -> { where(specimen: true) }
    scope :without_specimen,
          -> { where(specimen: false) }
    scope :with_sequences,
          -> { joins(:sequences).distinct }
    # much faster than `missing(:sequences)` which uses left outer join.
    scope :without_sequences,
          -> { where.not(id: with_sequences) }
    # confidence between min & max, in percentages
    scope :confidence, lambda { |min, max = min|
      where(vote_cache: (min.to_f / (100 / 3))..(max.to_f / (100 / 3)))
    }
    scope :with_comments,
          -> { joins(:comments).distinct }
    scope :without_comments,
          -> { where.not(id: Observation.with_comments) }
    scope :comments_contain, lambda { |phrase|
      joins(:comments).
        search_columns((Comment[:summary] + Comment[:comment]), phrase).distinct
    }
    scope :for_project, lambda { |project|
      joins(:project_observations).
        where(ProjectObservation[:project_id].eq(project.id)).distinct
    }
    scope :in_herbarium, lambda { |herbarium|
      joins(:herbarium_records).
        where(HerbariumRecord[:herbarium_id].eq(herbarium.id)).distinct
    }
    scope :herbarium_record_notes_contain, lambda { |phrase|
      joins(:herbarium_records).search_columns(HerbariumRecord[:notes], phrase)
    }
    scope :on_species_list, lambda { |species_list|
      joins(:species_list_observations).
        where(SpeciesListObservation[:species_list_id].eq(species_list.id)).
        distinct
    }
    scope :on_species_list_of_project, lambda { |project|
      joins(species_lists: :project_species_lists).
        where(ProjectSpeciesList[:project_id].eq(project.id)).distinct
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
