# frozen_string_literal: true

# Submit button — `<button type="submit">` with full Button styling.
# For plain text submit, pass `name:`. For rich content (icon + label
# spans), pass a block and omit `name:`.
#
# `submits_with:` and `disable_with:` wire Turbo's in-flight state.
# `disable_with:` defaults to `name:` when set.
#
# @example Plain text
#   Button(type: :submit, name: :save.ti)
#
# @example Rich content (block form)
#   Button(type: :submit,
#     variant: :outline, class: "px-2"
#   ) do
#     span(class: "d-sm-none") { render(Components::Icon.new(type: :search)) }
#     span(class: "hidden-xs") { plain(:search.ti) }
#   end
#
class Components::Button::Submit < Components::Button
  def initialize(name: nil, submits_with: nil, disable_with: nil,
                 html_name: nil, **opts)
    raise(ArgumentError.new("variant: :strip not valid on Submit")) if
      opts[:variant] == :strip

    @submits_with = submits_with
    @disable_with = disable_with || name
    @html_name = html_name
    super(name: name, type: "submit", **opts)
  end

  private

  def extra_attrs
    turbo = {}
    turbo[:turbo_submits_with] = @submits_with if @submits_with
    turbo[:disable_with] = @disable_with if @disable_with
    result = turbo.any? ? super.deep_merge(data: turbo) : super
    @html_name ? { name: @html_name }.merge(result) : result
  end
end
