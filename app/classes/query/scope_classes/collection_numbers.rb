# frozen_string_literal: true

class Query::ScopeClasses::CollectionNumbers < Query::BaseAR
  def model
    CollectionNumber
  end

  def self.parameter_declarations
    super.merge(
      created_at: [:time],
      updated_at: [:time],
      id_in_set: [CollectionNumber],
      by_users: [User],
      observations: [Observation],
      pattern: :string,
      names: [:string],
      numbers: [:string],
      name_has: :string,
      number_has: :string
    )
  end

  def initialize_flavor
    add_sort_order_to_title
    # add_owner_and_time_stamp_conditions
    # add_id_in_set_condition
    initialize_parameter_set(parameter_declarations.keys)
    add_pattern_condition
    super
  end

  def search_fields
    (CollectionNumber[:name] + CollectionNumber[:number])
  end

  def self.default_order
    :name_and_number
  end
end
