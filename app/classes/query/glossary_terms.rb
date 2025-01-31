# frozen_string_literal: true

class Query::GlossaryTerms < Query::Base
  def model
    ::GlossaryTerm
  end

  def parameter_declarations
    super.merge(
      created_at: [:time],
      updated_at: [:time],
      users: [User],
      name_has: :string,
      description_has: :string,
      pattern: :string
    )
  end

  def initialize_flavor
    add_sort_order_to_title
    add_owner_and_time_stamp_conditions
    add_pattern_condition
    add_search_condition("glossary_terms.name", params[:name_has])
    add_search_condition("glossary_terms.description", params[:description_has])
    super
  end

  def search_fields
    "CONCAT(" \
      "glossary_terms.name," \
      "COALESCE(glossary_terms.description,'')" \
      ")"
  end

  def self.default_order
    "name"
  end
end
