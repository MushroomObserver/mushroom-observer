# frozen_string_literal: true

class Tab::NameDescription::VersionActions < Tab::Collection
  def initialize(description:, desc_title:)
    super()
    @description = description
    @desc_title = desc_title
  end

  private

  def tabs
    [Tab::Object::Return.new(
      object: @description,
      title: :show_name_description.t(description: @desc_title)
    )]
  end
end
