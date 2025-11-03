# frozen_string_literal: true

# Component for rendering panel headings.
#
# @example Basic heading
#   render Components::PanelHeading.new do
#     "Title"
#   end
#
# @example Heading with formatted content
#   render Components::PanelHeading.new do
#     strong { "Bold Title" }
#   end
class Components::PanelHeading < Components::Base
  def view_template
    div(class: "panel-heading") do
      h4(class: "panel-title") do
        yield if block_given?
      end
    end
  end
end
