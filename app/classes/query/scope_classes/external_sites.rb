# frozen_string_literal: true

class Query::ScopeClasses::ExternalSites < Query::BaseAR
  def model
    ExternalSite
  end

  def self.parameter_declarations
    super.merge(
      ids: [ExternalSite],
      name_has: :string
    )
  end

  def initialize_flavor
    add_sort_order_to_title
    add_id_in_set_condition
    add_simple_search_condition(:name)
    super
  end

  def initialize_matching_scope_parameters
    [:name_has].each do |param|
      next unless params[param]

      @scopes = @scopes.send(param, params[param])
    end
  end

  def self.default_order
    :name
  end
end
