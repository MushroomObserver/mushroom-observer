# frozen_string_literal: true

# Action-nav for the glossary_term edit form.
class Tab::GlossaryTerm::FormEdit < Tab::Collection
  def initialize(term:)
    super()
    @term = term
  end

  private

  def tabs
    [Tab::Object::Return.new(object: @term),
     Tab::GlossaryTerm::Index.new]
  end
end
