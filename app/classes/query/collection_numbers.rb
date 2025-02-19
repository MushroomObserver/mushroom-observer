# frozen_string_literal: true

class Query::CollectionNumbers < Query::Base
  def model
    CollectionNumber
  end

  def self.parameter_declarations
    super.merge(
      created_at: [:time],
      updated_at: [:time],
      id_range: [:integer],
      users: [User],
      observation: Observation,
      observations: [Observation],
      pattern: :string,
      name: [:string],
      number: [:string],
      name_has: :string,
      number_has: :string
    )
  end

  def initialize_flavor
    add_sort_order_to_title
    add_owner_and_time_stamp_conditions
    add_for_observation_condition
    initialize_observations_parameter
    add_pattern_condition
    add_exact_match_condition("collection_numbers.name", params[:name])
    add_exact_match_condition("collection_numbers.number", params[:number])
    add_search_condition("collection_numbers.name", params[:name_has])
    add_search_condition("collection_numbers.number", params[:number_has])
    super
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
