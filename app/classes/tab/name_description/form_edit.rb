# frozen_string_literal: true

# Form-edit action-nav for NameDescription. Does NOT include the
# "adjust permissions" tab (which depends on `description.is_admin?
# (user)` AND the unconverted `descriptions_helper`
# adjust_description_permissions_tab). The helper-method delegator
# composes that tab onto the end if applicable.
class Tab::NameDescription::FormEdit < Tab::Collection
  def initialize(description:)
    super()
    @description = description
  end

  private

  def tabs
    [
      Tab::Object::Return.new(object: @description.name,
                              title: :show_object.t(type: :name)),
      Tab::Object::Return.new(object: @description)
    ]
  end
end
