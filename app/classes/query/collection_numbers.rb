# frozen_string_literal: true

class Query::CollectionNumbers < Query::Base
  def model
    @model ||= CollectionNumber
  end

  def list_by
    @list_by ||= :name
  end

  def self.parameter_declarations
    super.merge(
      created_at: [:time],
      updated_at: [:time],
      id_in_set: [CollectionNumber],
      collectors: [:string],
      numbers: [:string],
      collector_has: :string,
      number_has: :string,
      by_users: [User],
      observations: [Observation],
      pattern: :string
    )
  end

  def initialize_flavor
    add_owner_and_time_stamp_conditions
    add_id_in_set_condition
    add_collection_number_conditions
    initialize_observations_parameter
    add_pattern_condition
    super
  end

  def add_collection_number_conditions
    add_exact_match_condition("collection_numbers.name", params[:collectors])
    add_exact_match_condition("collection_numbers.number", params[:numbers])
    add_search_condition("collection_numbers.name", params[:collector_has])
    add_search_condition("collection_numbers.number", params[:number_has])
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
