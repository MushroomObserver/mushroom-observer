# frozen_string_literal: true

# "Show this glossary term" action-nav link. Title carries the term
# name (`:show_glossary_term.t(glossary_term: …)`), distinct from
# `Tab::Object::Show`'s generic `:show_object.t(type: :glossary_term)`.
class Tab::GlossaryTerm::Show < Tab::Base
  def initialize(term:)
    super()
    @term = term
  end

  def title
    :show_glossary_term.t(glossary_term: @term.name)
  end

  def path
    glossary_term_path(@term.id)
  end

  def html_options
    { class: "glossary_term_link" }
  end
end
