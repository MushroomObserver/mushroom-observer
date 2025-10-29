# frozen_string_literal: true

# Component for rendering panel body content.
#
# @example Basic body
#   render Components::Panel::Body.new(content: "Panel content")
#
# @example Body with custom class
#   render Components::Panel::Body.new(
#     content: "Panel content",
#     inner_class: "custom-class"
#   )
class Components::Panel::Body < Components::Base
  prop :content, String
  prop :inner_class, _Nilable(String), default: nil
  prop :inner_id, _Nilable(String), default: nil

  def view_template
    div(
      class: class_names("panel-body", @inner_class),
      id: @inner_id
    ) do
      # Content may contain HTML from Rails helpers (e.g., link_to, form
      # elements) that needs to be rendered as HTML, not escaped as text
      # rubocop:disable Rails/OutputSafety
      raw(@content.html_safe)
      # rubocop:enable Rails/OutputSafety
    end
  end
end
