# frozen_string_literal: true

class Tab::LocationDescription::FormPermissions < Tab::Collection
  def initialize(description:)
    super()
    @description = description
  end

  private

  def tabs
    [
      Tab::Object::Return.new(object: @description.location),
      Tab::Object::Return.new(
        object: @description,
        title: :show_object.t(type: :location_description)
      )
    ]
  end
end
