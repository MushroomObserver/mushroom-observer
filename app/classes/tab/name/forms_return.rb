# frozen_string_literal: true

# Action-nav for various name forms — just a cancel-to-show link.
class Tab::Name::FormsReturn < Tab::Collection
  def initialize(name:)
    super()
    @name = name
  end

  private

  def tabs
    [Tab::Object::Return.new(object: @name)]
  end
end
