# frozen_string_literal: true

class Query::ScopeClasses::CollectionNumbers < Query::BaseAR
  def model
    CollectionNumber
  end

  def self.parameter_declarations
    super.merge(
      created_at: [:time],
      updated_at: [:time],
      ids: [CollectionNumber],
      by_users: [User],
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
    add_id_in_set_condition
    add_collection_number_conditions
    initialize_observations_parameter
    add_pattern_condition
    super
  end

  def add_collection_number_conditions
    add_exact_match_condition(CollectionNumber[:name], params[:name])
    add_exact_match_condition(CollectionNumber[:number], params[:number])
    add_simple_search_condition(:name)
    add_simple_search_condition(:number)
  end

  def search_fields
    (CollectionNumber[:name] + CollectionNumber[:number])
  end

  def self.default_order
    :name_and_number
  end
end
