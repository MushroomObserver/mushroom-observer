# frozen_string_literal: true

class Tab::Name::VersionActions < Tab::Collection
  def initialize(name:)
    super()
    @name = name
  end

  private

  def tabs
    [Tab::Object::Show.new(
      object: @name,
      title: :show_name.t(name: @name.display_name)
    )]
  end
end
