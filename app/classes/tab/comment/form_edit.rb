# frozen_string_literal: true

# Action-nav for the comment edit form.
class Tab::Comment::FormEdit < Tab::Collection
  def initialize(comment:)
    super()
    @comment = comment
  end

  private

  def tabs
    [Tab::Object::Return.new(object: @comment)]
  end
end
