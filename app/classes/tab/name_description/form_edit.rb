# frozen_string_literal: true

# Form-edit action-nav for NameDescription. Appends an
# `AdjustPermissions` tab when the caller's `admin` flag is set
# (`description.is_admin?(user) || in_admin_mode?` — the latter
# being a controller-side flag, so it must be passed in).
class Tab::NameDescription::FormEdit < Tab::Collection
  def initialize(description:, admin: false)
    super()
    @description = description
    @admin = admin
  end

  private

  def tabs
    [
      Tab::Object::Return.new(object: @description.name,
                              title: :show_object.t(type: :name)),
      Tab::Object::Return.new(object: @description),
      admin_tab
    ].compact
  end

  def admin_tab
    return unless @admin

    Tab::Description::AdjustPermissions.new(description: @description)
  end
end
