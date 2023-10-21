# frozen_string_literal: true

module Query
  class GlossaryTermBase < Query::Base
    def model
      GlossaryTerm
    end

    def parameter_declarations
      super.merge(
        created_at?: [:time],
        updated_at?: [:time],
        users?: [User],
        name_has?: :string,
        description_has?: :string
      )
    end

    def initialize_flavor
      add_owner_and_time_stamp_conditions("glossary_terms")
      add_search_condition("glossary_terms.name", params[:name_has])
      add_search_condition("glossary_terms.description",
                           params[:description_has])
      super
    end

    def self.default_order
      "name"
    end
  end
end
