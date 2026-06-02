# frozen_string_literal: true

# Action-nav for the publication edit form.
class Tab::Publication::FormEdit < Tab::Collection
  def initialize(publication:)
    super()
    @publication = publication
  end

  private

  def tabs
    [Tab::Object::Return.new(object: @publication),
     Tab::Publication::Index.new]
  end
end
