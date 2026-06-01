# frozen_string_literal: true

# "Edit glossary term" action-nav link.
class Tab::GlossaryTerm::Edit < Tab::Base
  def initialize(term:)
    super()
    @term = term
  end

  def title
    :edit_glossary_term.t
  end

  def path
    edit_glossary_term_path(@term.id)
  end

  def html_options
    { class: "edit_glossary_term_link" }
  end
end
