# frozen_string_literal: true

# Component for rendering collapsible panel headings.
# Renders a clickable heading that toggles a collapsible panel body.
#
# @example Basic collapsible heading
#   render Components::PanelCollapseHeading.new(
#     target: "my_panel_body",
#     open: true
#   ) { "Click to collapse" }
#
# @example Collapsible heading with collapse message
#   render Components::PanelCollapseHeading.new(
#     target: "details_panel",
#     open: false,
#     collapse_message: "MORE"
#   ) { "Details" }
class Components::PanelCollapseHeading < Components::Base
  include ActionView::Helpers::UrlHelper
  include ApplicationHelper

  prop :target, String
  prop :open, _Boolean, default: false
  prop :collapse_message, _Nilable(String), default: nil

  def view_template
    div(class: "panel-heading") do
      h4(class: "panel-title") do
        link_to(
          "##{@target}",
          class: class_names("panel-collapse-trigger", collapsed_class),
          role: "button",
          data: { toggle: "collapse" },
          aria: { expanded: @open, controls: @target }
        ) do
          yield if block_given?
          span(class: "float-right") { render_collapse_icons }
        end
      end
    end
  end

  private

  def collapsed_class
    @open ? "" : "collapsed"
  end

  def render_collapse_icons
    if @collapse_message.present?
      span(class: "font-weight-normal mr-2") do
        plain(@collapse_message)
      end
    end

    chevron_down = link_icon(:chevron_down, title: :OPEN.l,
                                            class: "active-icon")
    chevron_up = link_icon(:chevron_up, title: :CLOSE.l)

    # rubocop:disable Rails/OutputSafety
    raw("#{chevron_down} #{chevron_up}")
    # rubocop:enable Rails/OutputSafety
  end
end
