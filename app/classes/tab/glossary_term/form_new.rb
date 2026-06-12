# frozen_string_literal: true

# Action-nav for the glossary_term new form.
class Tab::GlossaryTerm::FormNew < Tab::Collection
  private

  def tabs
    [Tab::GlossaryTerm::Index.new]
  end
end
