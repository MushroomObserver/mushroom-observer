# frozen_string_literal: true

# Action-nav for the glossary_term version (history) page.
class Tab::GlossaryTerm::VersionActions < Tab::Collection
  def initialize(term:)
    super()
    @term = term
  end

  private

  def tabs
    [Tab::GlossaryTerm::Show.new(term: @term)]
  end
end
