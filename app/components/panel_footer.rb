# frozen_string_literal: true

# Component for rendering panel footer content.
#
# @example Basic footer
#   render Components::PanelFooter.new(footer: "Footer content")
class Components::PanelFooter < Components::Base
  prop :footer, String

  def view_template
    div(class: "panel-footer") do
      # Footer may contain HTML from Rails helpers (e.g., link_to, buttons)
      # that needs to be rendered as HTML, not escaped as text
      # rubocop:disable Rails/OutputSafety
      raw(@footer.html_safe)
      # rubocop:enable Rails/OutputSafety
    end
  end
end
