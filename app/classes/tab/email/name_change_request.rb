# frozen_string_literal: true

# Action-nav for the admin email name-change-request form.
class Tab::Email::NameChangeRequest < Tab::Collection
  def initialize(name:)
    super()
    @name = name
  end

  private

  def tabs
    [Tab::Object::Return.new(object: @name)]
  end
end
