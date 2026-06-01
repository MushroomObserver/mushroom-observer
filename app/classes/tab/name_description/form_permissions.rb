# frozen_string_literal: true

class Tab::NameDescription::FormPermissions < Tab::Collection
  def initialize(description:)
    super()
    @description = description
  end

  private

  def tabs
    [
      Tab::Object::Return.new(object: @description.name),
      Tab::Object::Return.new(
        object: @description,
        title: :show_object.t(type: :name_description)
      )
    ]
  end
end
