# frozen_string_literal: true

class Tab::LocationDescription::FormNew < Tab::Collection
  def initialize(description:)
    super()
    @description = description
  end

  private

  def tabs
    [Tab::Object::Return.new(object: @description.location)]
  end
end
