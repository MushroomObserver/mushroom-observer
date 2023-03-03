# frozen_string_literal: true

class Query::GlossaryTermBase < Query::Base
  def model
    GlossaryTerm
  end

  def parameter_declarations
    super.merge(
      created_at?: [:time],
      updated_at?: [:time],
      users?: [User],
      title_has?: :string,
      body_has?: :string
    )
  end

  def initialize_flavor
    add_owner_and_time_stamp_conditions("glossary_terms")
    add_search_condition("glossary_terms.title", params[:title_has])
    add_search_condition("glossary_terms.body", params[:body_has])
    super
  end

  def self.default_order
    "created_at"
  end
end
