# frozen_string_literal: true

# GET link to the new-form route — delegates to `Components::Link::New`,
# adding button styling. Defaults to `btn btn-default`.
# Pass `variant:` to override (e.g. `variant: :outline`, `variant: :strip`).
#
# Always pass `target:` as an explicit string path — new-form routes
# often require extra params (e.g. `observation_id:`) that a model-
# instance target cannot express.
#
# @example outline "New" button
#   Button(type: :new,
#     target: new_name_description_path(@name.id),
#     name: :show_name_create_description.t,
#     variant: :outline
#   )
class Components::Button::New < Components::Link::New
  def initialize(target: nil, name: nil, icon: :add, variant: nil, **opts)
    tab = opts.delete(:tab)
    super(target: target, tab: tab, name: name, icon: icon,
          button: variant, **opts)
  end

  private

  def btn_styling
    return nil if @button == :strip

    class_names("btn", btn_class(@button))
  end
end
