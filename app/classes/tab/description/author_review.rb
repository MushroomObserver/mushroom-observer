# frozen_string_literal: true

# Action-nav for the description authors review page. The object is
# the description being authored; the parent is its name / location.
class Tab::Description::AuthorReview < Tab::Collection
  def initialize(object:)
    super()
    @object = object
  end

  private

  def tabs
    [Tab::Object::ShowParent.new(object: @object),
     Tab::Object::Show.new(object: @object)]
  end
end
