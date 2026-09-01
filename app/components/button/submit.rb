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
#     span(class: "d-sm-none") { Icon(type: :search) }
#     span(class: class_names(
#            Components::Column.mobile_hide_classes(display: :inline)
#          )) do
#       plain(:search.ti)
#     end
#   end
#
class Components::Button::Submit < Components::Button
  prop :submits_with, _Nilable(String), default: nil
  prop :disable_with, _Nilable(String), default: nil
  prop :html_name, _Nilable(String), default: nil

  # `disable_with:` defaults to `name:` when the caller omits it.
  # `validate_no_btn_classes!` is called explicitly here since
  # declaring new props on this subclass makes Literal's generated
  # super chain skip Button's own hand-written initialize body (see
  # Button::CRUDBase for the same gotcha).
  def initialize(name: nil, disable_with: nil, **opts)
    raise(ArgumentError.new("variant: :strip not valid on Submit")) if
      opts[:variant] == :strip

    validate_no_btn_classes!(opts[:class])
    super(name: name, disable_with: disable_with || name, type: "submit",
          **opts)
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
