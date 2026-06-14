# frozen_string_literal: true

module Views::Controllers::GlossaryTerms
  # Wrap of `GlossaryTerms::Form` for the edit flow.
  # Converted from `glossary_terms/edit.html.erb`.
  class Edit < Views::Base
    prop :glossary_term, ::GlossaryTerm

    def view_template
      add_edit_title(@glossary_term)
      add_context_nav(::Tab::GlossaryTerm::FormEdit.new(term: @glossary_term))

      render(Form.new(@glossary_term))
    end
  end
end
