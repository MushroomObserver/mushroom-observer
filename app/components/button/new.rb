# frozen_string_literal: true

# GET button with new-form-action defaults: `action: :new`, `icon: :add`.
# Defaults to the standard btn frame. Pass `variant: :strip` for a bare
# add icon, `variant: :outline` for an outline button, or `icon: nil`
# to suppress the icon.
#
# Always pass `target:` as an explicit string path — new-form routes
# often require extra params (e.g. `observation_id:`) that a model-
# instance target can't express. Pass an explicit `name:` for any label
# other than the generic "Add" fallback.
#
# @example bare add icon (no btn frame)
#   render(Components::Button::New.new(
#     target: new_herbarium_path,
#     name: :new_object.t(type: :herbarium),
#     variant: :strip
#   ))
#
# @example outline "New" button
#   render(Components::Button::New.new(
#     target: new_name_description_path(@name.id),
#     name: :show_name_create_description.t,
#     variant: :outline
#   ))
class Components::Button::New < Components::Button::Get
  def initialize(target:, name: nil, icon: :add, **)
    super(target: target,
          name: name || :ADD.l,
          action: :new,
          icon: icon,
          **)
  end
end
