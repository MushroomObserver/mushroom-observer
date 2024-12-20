# frozen_string_literal: true

module Query
  # methods for initializing Query's for Observations
  class ObservationBase < Query::Base
    include Query::Initializers::Names
    include Query::Initializers::Observations
    include Query::Initializers::Locations
    include Query::Initializers::ContentFilters
    include Query::Initializers::AdvancedSearch

    def model
      Observation
    end

    def parameter_declarations
      super.merge(local_parameter_declarations).
        merge(observations_parameter_declarations).
        merge(bounding_box_parameter_declarations).
        merge(content_filter_parameter_declarations(Observation)).
        merge(names_parameter_declarations).
        merge(naming_consensus_parameter_declarations).
        merge(advanced_search_parameter_declarations)
    end

    def local_parameter_declarations
      {
        # dates/times
        date?: [:date],
        created_at?: [:time],
        updated_at?: [:time],

        ids?: [Observation],
        herbarium_records?: [:string],
        project_lists?: [:string],
        by_user?: User,
        by_editor?: User, # for coercions from name/location
        users?: [User],
        field_slips?: [:string],
        pattern?: :string,
        regexp?: :string, # for coercions from location
        needs_naming?: :boolean,
        in_clade?: :string,
        in_region?: :string
      }
    end

    # rubocop:disable Metrics/AbcSize
    def initialize_flavor
      add_ids_condition
      add_owner_and_time_stamp_conditions("observations")
      add_by_user_condition("observations")
      add_date_condition("observations.when", params[:date])
      add_pattern_condition
      add_advanced_search_conditions
      add_needs_naming_condition
      initialize_name_parameters
      initialize_association_parameters
      initialize_boolean_parameters
      initialize_search_parameters
      add_range_condition("observations.vote_cache", params[:confidence])
      add_bounding_box_conditions_for_observations
      initialize_content_filters(Observation)
      super
    end
    # rubocop:enable Metrics/AbcSize

    def add_pattern_condition
      return if params[:pattern].blank?

      add_join(:names)
      super
    end

    def add_advanced_search_conditions
      return if advanced_search_params.all? { |key| params[key].blank? }

      initialize_advanced_search
    end

    def initialize_association_parameters
      add_where_condition("observations", params[:locations])
      add_at_location_condition
      initialize_herbaria_parameter
      initialize_herbarium_records_parameter
      add_for_project_condition(:project_observations,
                                [:observations, :project_observations])
      initialize_projects_parameter
      initialize_project_lists_parameter
      add_in_species_list_condition
      initialize_species_lists_parameter
      initialize_field_slips_parameter
    end

    def initialize_field_slips_parameter
      return unless params[:field_slips]

      add_join(:field_slips)
      add_exact_match_condition(
        "field_slips.code",
        params[:field_slips]
      )
    end

    def add_needs_naming_condition
      return unless params[:needs_naming]

      user = User.current_id
      # 15x faster to use this AR scope to assemble the IDs vs using
      # SQL SELECT DISTINCT
      where << Observation.needs_naming_and_not_reviewed_by_user(user).
               to_sql.gsub(/^.*?WHERE/, "")

      # additional filters:
      add_name_in_clade_condition
      add_location_in_region_condition
      # add_by_user_condition
    end

    # from content_filter/clade.rb
    # parse_name and check the already initialize_unfiltered list of
    # observations against observations.classification.
    # Some inefficiency here comes from having to parse the name from a string.
    # NOTE: Write an in_clade autocompleter that passes the name_id as val
    def add_name_in_clade_condition
      return unless params[:in_clade]

      val = params[:in_clade]
      name, rank = parse_name(val)
      conds = if Name.ranks_above_genus.include?(rank)
                "observations.text_name = '#{name}' OR " \
                "observations.classification REGEXP '#{rank}: _#{name}_'"
              else
                "observations.text_name = '#{name}' OR " \
                "observations.text_name REGEXP '^#{name} '"
              end
      where << conds
    end

    def parse_name(val)
      name = Name.best_match(val)
      return [name.text_name, name.rank] if name

      [val, Name.guess_rank(val) || "Genus"]
    end

    # from content_filter/region.rb, but simpler.
    # includes region itself (i.e., no comma before region in 2nd regex)
    def add_location_in_region_condition
      return unless params[:in_region]

      region = params[:in_region]
      region = Location.reverse_name_if_necessary(region)

      conds = if Location.understood_continent?(region)
                countries = Location.countries_in_continent(region).join("|")
                "observations.where REGEXP #{escape(", (#{countries})$")}"
              else
                "observations.where LIKE #{escape("%#{region}")}"
              end
      where << conds
    end

    # The tricky thing here is, without the user.id being the value passed in
    # params[:filter][:term], we're hunting for a user from a string like
    # "Name <name>". Better to have the id as the value!
    # Below uses the method in query/initializers/advanced_search to get a
    # string but is expensive. Something like
    # joins(:users).where((User[:login] + User[:name]).matches(str))
    # def add_by_user_condition
    #   return unless params[:by_user]
    #
    #   user = find_cached_parameter_instance(User, :by_user)
    #   user = params[:by_user].to_s.gsub(/ *<[^<>]*>/, "")
    # end

    def initialize_boolean_parameters
      initialize_is_collection_location_parameter
      initialize_with_public_lat_lng_parameter
      initialize_with_name_parameter
      initialize_with_notes_parameter
      add_with_notes_fields_condition(params[:with_notes_fields])
      add_join(:comments) if params[:with_comments]
      add_join(:sequences) if params[:with_sequences]
    end

    def add_join_to_names
      add_join(:names)
    end

    def add_join_to_users
      add_join(:users)
    end

    def add_join_to_locations
      add_join(:locations!)
    end

    def content_join_spec
      :comments
    end

    def search_fields
      "CONCAT(" \
        "names.search_name," \
        "observations.where" \
        ")"
    end

    def self.default_order
      "date"
    end
  end
end
