# frozen_string_literal: true

# Component for rendering panel footer content.
#
# @example Basic footer
#   render Components::PanelFooter.new do
#     "Footer content"
#   end
#
# @example Footer with formatted content
#   render Components::PanelFooter.new do
#     link_to("View more", path)
#   end
class Components::PanelFooter < Components::Base
  def view_template
    div(class: "panel-footer") do
      yield if block_given?
    end
  end
end
