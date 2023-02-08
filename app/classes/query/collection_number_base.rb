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
      observations?: [:string],
      name?: [:string],
      number?: [:string],
      name_has?: :string,
      number_has?: :string
    )
  end

  def initialize_flavor
    add_owner_and_time_stamp_conditions("collection_numbers")
    add_id_condition("observation_collection_numbers.observation_id",
                     params[:observations], :observation_collection_numbers)
    add_exact_match_condition("collection_numbers.name", params[:name])
    add_exact_match_condition("collection_numbers.number", params[:number])
    add_search_condition("collection_numbers.name", params[:name_has])
    add_search_condition("collection_numbers.number", params[:number_has])
    super
  end

  def self.default_order
    "name_and_number"
  end
end
