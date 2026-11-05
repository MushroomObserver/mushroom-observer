# frozen_string_literal: true

module Views::Controllers::GlossaryTerms
  # Wrap of `GlossaryTerms::Form` for the edit flow.
  class Edit < Views::FullPageBase
    prop :glossary_term, ::GlossaryTerm

    def view_template
      add_edit_title(@glossary_term)
      add_context_nav(::Tab::GlossaryTerm::FormEdit.new(term: @glossary_term))

      render(Form.new(@glossary_term))
    end
  end
end
