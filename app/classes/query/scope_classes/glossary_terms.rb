# frozen_string_literal: true

class Query::ScopeClasses::GlossaryTerms < Query::BaseAR
  def model
    ::GlossaryTerm
  end

  def self.parameter_declarations
    super.merge(
      created_at: [:time],
      updated_at: [:time],
      by_users: [User],
      name_has: :string,
      description_has: :string,
      pattern: :string
    )
  end

  def initialize_flavor
    add_sort_order_to_title
    initialize_parameter_set(parameter_declarations.keys)
    add_pattern_condition
    super
  end

  def search_fields
    (GlossaryTerm[:name] + GlossaryTerm[:description].coalesce(""))
  end

  def self.default_order
    :name
  end
end
