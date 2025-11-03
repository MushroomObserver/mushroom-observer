# frozen_string_literal: true

# Component for rendering panel body content.
#
# @example Basic body
#   render Components::PanelBody.new do
#     "Panel content"
#   end
#
# @example Body with formatted content
#   render Components::PanelBody.new do
#     p { "Paragraph content" }
#     ul do
#       li { "Item 1" }
#       li { "Item 2" }
#     end
#   end
class Components::PanelBody < Components::Base
  def view_template
    div(class: "panel-body") do
      yield if block_given?
    end
  end
end
