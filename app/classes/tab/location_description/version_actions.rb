# frozen_string_literal: true

class Tab::LocationDescription::VersionActions < Tab::Collection
  def initialize(description:, desc_title:)
    super()
    @description = description
    @desc_title = desc_title
  end

  private

  def tabs
    [Tab::Object::Return.new(
      object: @description,
      title: :show_location_description.t(description: @desc_title)
    )]
  end
end
