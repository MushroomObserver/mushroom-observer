# frozen_string_literal: true

class Query::Sequences < Query::Base
  include Query::Params::Locations
  include Query::Params::Names
  include Query::Params::Observations
  include Query::Initializers::Names
  include Query::Initializers::Observations

  def model
    Sequence
  end

  def parameter_declarations
    super.merge(sequence_parameter_declarations).
      merge(observation_parameter_declarations)
      # merge(names_parameter_declarations). nope. send obs_query
      # merge(bounding_box_parameter_declarations)
  end

  def sequence_parameter_declarations
    {
      created_at: [:time],
      updated_at: [:time],
      ids: [Sequence],
      users: [User],
      observations: [Observation],
      locus: [:string],
      archive: [:string],
      accession: [:string],
      locus_has: :string,
      accession_has: :string,
      notes_has: :string,
      pattern: :string
    }
  end

  def observation_parameter_declarations
    {
      obs_date: [:date],
      observers: [User],
      with_name: :boolean,
      confidence: [:float],
      locations: [Location],
      is_collection_location: :boolean,
      with_images: :boolean,
      with_specimen: :boolean,
      with_obs_notes: :boolean,
      obs_notes_has: :string,
      with_notes_fields: [:string],
      herbaria: [Herbarium],
      herbarium_records: [HerbariumRecord],
      projects: [Project],
      species_lists: [SpeciesList]
    }
  end

  def initialize_flavor
    add_sort_order_to_title
    # Leaving out bases because some formats allow spaces and other "garbage"
    # delimiters which could interrupt the subsequence the user is searching
    # for.  Users would probably not understand why the search fails to find
    # some sequences because of this.
    add_owner_and_time_stamp_conditions
    add_pattern_condition
    add_ids_condition
    initialize_association_parameters
    initialize_name_parameters(:observations)
    initialize_observation_parameters
    initialize_exact_match_parameters
    initialize_boolean_parameters
    initialize_search_parameters
    add_bounding_box_conditions_for_observations
    super
  end

  def search_fields
    # I'm leaving out bases because it would be misleading.  Some formats
    # allow spaces and other delimiting "garbage" which could break up
    # the subsequence the user is searching for.
    "CONCAT(" \
      "COALESCE(sequences.locus,'')," \
      "COALESCE(sequences.archive,'')," \
      "COALESCE(sequences.accession,'')," \
      "COALESCE(sequences.notes,'')" \
      ")"
  end

  def initialize_association_parameters
    initialize_observations_parameter(:sequences)
    initialize_observers_parameter
    add_where_condition(:observations, params[:locations], :observations)
    initialize_herbaria_parameter
    initialize_herbarium_records_parameter
    initialize_projects_parameter
    initialize_species_lists_parameter
  end

  # Different because it can take multiple users
  def initialize_observers_parameter
    add_id_condition("observations.user_id", params[:observers], :observations)
  end

  def initialize_observation_parameters
    initialize_obs_date_parameter(:obs_date)
    initialize_is_collection_location_parameter
    initialize_confidence_parameter
  end

  def initialize_exact_match_parameters
    add_exact_match_condition("sequences.locus", params[:locus])
    add_exact_match_condition("sequences.archive", params[:archive])
    add_exact_match_condition("sequences.accession", params[:accession])
  end

  def initialize_boolean_parameters
    initialize_with_images_parameter
    initialize_with_specimen_parameter
    initialize_with_name_parameter
    initialize_obs_with_notes_parameter(:with_obs_notes)
    add_with_notes_fields_condition(params[:with_notes_fields], :observations)
  end

  def initialize_search_parameters
    add_search_condition("sequences.locus", params[:locus_has])
    add_search_condition("sequences.accession", params[:accession_has])
    add_search_condition("sequences.notes", params[:notes_has])
    add_search_condition("observations.notes", params[:obs_notes_has],
                         :observations)
  end

  def add_join_to_locations
    add_join(:observations, :locations!)
  end

  def self.default_order
    "created_at"
  end
end
