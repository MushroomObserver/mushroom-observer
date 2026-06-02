# frozen_string_literal: true

# Action-nav for the comment new form.
class Tab::Comment::FormNew < Tab::Collection
  def initialize(target:)
    super()
    @target = target
  end

  private

  def tabs
    [Tab::Object::Return.new(object: @target)]
  end
end
