# frozen_string_literal: true

# Submit button — `<button type="submit">` with full Button styling.
# For plain text submit, pass `name:`. For rich content (icon + label
# spans), pass a block and omit `name:`.
#
# `submits_with:` and `disable_with:` wire Turbo's in-flight state.
# `disable_with:` defaults to `name:` when set.
#
# @example Plain text
#   render(Components::Button::Submit.new(name: :SAVE.l))
#
# @example Rich content (block form)
#   render(Components::Button::Submit.new(
#     style: :outline_default, class: "px-2"
#   )) do
#     span(class: "d-sm-none") { render(Components::Icon.new(type: :search)) }
#     span(class: "hidden-xs") { plain(:SEARCH.l) }
#   end
#
class Components::Button::Submit < Components::Button
  def initialize(name: nil, submits_with: nil, disable_with: nil, **)
    @submits_with = submits_with
    @disable_with = disable_with || name
    super(name: name, type: "submit", **)
  end

  private

  def extra_attrs
    turbo = {}
    turbo[:turbo_submits_with] = @submits_with if @submits_with
    turbo[:disable_with] = @disable_with if @disable_with
    turbo.any? ? super.deep_merge(data: turbo) : super
  end
end
