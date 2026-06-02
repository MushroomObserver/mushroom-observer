# frozen_string_literal: true

# Action-nav for the glossary_term image attach/detach forms
# (images/reuse, images/remove).
class Tab::GlossaryTerm::ImageForm < Tab::Collection
  def initialize(term:)
    super()
    @term = term
  end

  private

  def tabs
    [Tab::Object::Return.new(object: @term),
     Tab::GlossaryTerm::Edit.new(term: @term)]
  end
end
