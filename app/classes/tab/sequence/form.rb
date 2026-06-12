# frozen_string_literal: true

# Action-nav for the sequence new + edit forms: back to the parent
# object (observation for `new`, back_object for `edit` — typically
# the observation too).
class Tab::Sequence::Form < Tab::Collection
  def initialize(back_object:)
    super()
    @back_object = back_object
  end

  private

  def tabs
    [Tab::Object::Return.new(object: @back_object)]
  end
end
