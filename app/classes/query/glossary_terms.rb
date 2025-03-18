# frozen_string_literal: true

class Query::GlossaryTerms < Query::BaseAR
  def model
    @model ||= GlossaryTerm
  end

  def list_by
    @list_by ||= GlossaryTerm[:name]
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

  # def initialize_flavor
  #   add_owner_and_time_stamp_conditions
  #   add_search_condition("glossary_terms.name", params[:name_has])
  #   add_search_condition("glossary_terms.description", params[:description_has])
  #   add_pattern_condition
  #   super
  # end

  # def search_fields
  #   "CONCAT(" \
  #     "glossary_terms.name," \
  #     "COALESCE(glossary_terms.description,'')" \
  #     ")"
  # end

  def self.default_order
    "name"
  end
end
