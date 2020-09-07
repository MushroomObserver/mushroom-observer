# frozen_string_literal: true

# View Helpers for GlossaryTerms
module GlossaryTermsHelper
  def glossary_term_destroy_button(term)
    destroy_button(object: term, name: :destroy_glossary_term)
  end
end
