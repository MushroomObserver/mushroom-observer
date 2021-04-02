# frozen_string_literal: true

# View Helpers for GlossaryTerms
module GlossaryTermsHelper
  def glossary_term_destroy_button(term)
    destroy_button(target: term, name: :destroy_object.t(type: :glossary_term))
  end
end
