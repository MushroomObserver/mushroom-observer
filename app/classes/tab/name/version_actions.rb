# frozen_string_literal: true

class Tab::Name::VersionActions < Tab::Collection
  def initialize(name:, user: nil)
    super()
    @name = name
    @user = user
  end

  private

  def tabs
    [Tab::Object::Show.new(
      object: @name,
      title: :show_name.t(name: @name.display_name(@user))
    )]
  end
end
