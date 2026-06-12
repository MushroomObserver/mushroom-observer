# frozen_string_literal: true

# "Glossary term index" action-nav link. Distinct title from
# `Tab::Object::Index` (uses the dedicated `:glossary_term_index.t`).
class Tab::GlossaryTerm::Index < Tab::Base
  def title
    :glossary_term_index.t
  end

  def path
    glossary_terms_path
  end

  def html_options
    { class: "glossary_terms_index_link" }
  end
end
