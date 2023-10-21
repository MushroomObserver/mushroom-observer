# frozen_string_literal: true

module Query
  class GlossaryTermPatternSearch < Query::GlossaryTermBase
    def parameter_declarations
      super.merge(
        pattern: :string
      )
    end

    def initialize_flavor
      add_search_condition(search_fields, params[:pattern])
      super
    end

    def search_fields
      "CONCAT(" \
        "glossary_terms.name," \
        "COALESCE(glossary_terms.description,'')" \
        ")"
    end
  end
end
