# frozen_string_literal: true

class Query::CollectionNumberBase < Query::Base
  def model
    CollectionNumber
  end

  def parameter_declarations
    super.merge(
      created_at?: [:time],
      updated_at?: [:time],
      users?: [User],
      observation?: Observation,
      observations?: [:string],
      pattern?: :string,
      name?: [:string],
      number?: [:string],
      name_has?: :string,
      number_has?: :string
    )
  end

  # rubocop:disable Metrics/AbcSize
  def initialize_flavor
    add_owner_and_time_stamp_conditions("collection_numbers")
    add_for_observation_condition
    add_pattern_condition
    add_id_condition("observation_collection_numbers.observation_id",
                     params[:observations], :observation_collection_numbers)
    add_exact_match_condition("collection_numbers.name", params[:name])
    add_exact_match_condition("collection_numbers.number", params[:number])
    add_search_condition("collection_numbers.name", params[:name_has])
    add_search_condition("collection_numbers.number", params[:number_has])
    super
  end
  # rubocop:enable Metrics/AbcSize

  def add_for_observation_condition
    return if params[:observation].blank?

    obs = find_cached_parameter_instance(Observation, :observation)
    @title_tag = :query_title_for_observation
    @title_args[:observation] = obs.unique_format_name
    where << "observation_collection_numbers.observation_id = '#{obs.id}'"
    add_join(:observation_collection_numbers)
  end

  def add_pattern_condition
    return if params[:pattern].blank?

    @title_tag = :query_title_pattern_search
    add_search_condition(search_fields, params[:pattern])
  end

  def search_fields
    "CONCAT(" \
      "collection_numbers.name," \
      "collection_numbers.number" \
      ")"
  end

  def self.default_order
    "name_and_number"
  end
end
