# frozen_string_literal: true

# GET link to the edit route — delegates to `Components::Link::Edit`,
# adding button styling. Defaults to `btn btn-default`.
# Pass `variant:` to override (e.g. `variant: :outline`, `variant: :strip`).
#
# @example default (btn-default frame with edit icon)
#   Button(type: :edit, target: @herbarium)
#
# @example outline button (common CRUD row usage)
#   Button(type: :edit, target: @herbarium,
#                                 variant: :outline)
#
# @example bare icon, no btn frame
#   Button(type: :edit, target: @herbarium,
#                                 variant: :strip)
class Components::Button::Edit < Components::Link::Edit
  def initialize(target:, name: nil, icon: :edit, variant: nil, **)
    super(target: target, name: name, icon: icon, button: variant, **)
  end

  private

  def btn_styling
    return nil if @button == :strip

    class_names("btn", btn_class(@button))
  end
end
