# frozen_string_literal: true

class Query::ScopeClasses::ExternalSites < Query::BaseAR
  def model
    ExternalSite
  end

  def self.parameter_declarations
    super.merge(
      id_in_set: [ExternalSite],
      name_has: :string
    )
  end

  def initialize_flavor
    add_sort_order_to_title
    initialize_parameter_set(parameter_declarations.keys)
    super
  end

  def self.default_order
    :name
  end
end
