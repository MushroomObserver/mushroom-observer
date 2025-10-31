# frozen_string_literal: true

# Component for rendering panel headings with optional collapse functionality.
#
# @example Basic heading
#   render Components::Panel::Heading.new(heading: "Title")
#
# @example Heading with links
#   render Components::Panel::Heading.new(
#     heading: "Title",
#     heading_links: link_to("Edit", edit_path)
#   )
#
# @example Collapsible heading
#   render Components::Panel::Heading.new(
#     heading: "Click to expand",
#     collapse: "my_panel",
#     open: false
#   )
class Components::Panel::Heading < Components::Base
  prop :heading, String
  prop :heading_links, _Nilable(String), default: nil
  prop :collapse, _Nilable(String), default: nil
  prop :collapse_message, _Nilable(String), default: nil
  prop :open, _Boolean, default: false

  def view_template
    div(class: "panel-heading") do
      if @collapse.present?
        render_collapsible_heading
      else
        render_static_heading
      end
    end
  end

  private

  def render_static_heading
    h4(class: "panel-title") do
      # heading may contain HTML (e.g., submit buttons, formatted text) that
      # needs to be rendered as HTML, not escaped as text
      # rubocop:disable Rails/OutputSafety
      raw(@heading.html_safe)
      # rubocop:enable Rails/OutputSafety
      if @heading_links.present?
        # heading_links contains HTML from link_to helper that needs to be
        # rendered as HTML, not escaped as text
        # rubocop:disable Rails/OutputSafety
        span(class: "float-right") { raw(@heading_links.html_safe) }
        # rubocop:enable Rails/OutputSafety
      end
    end
  end

  def render_collapsible_heading
    collapsed_class = @open ? "" : "collapsed"

    h4(class: "panel-title") do
      link_to(
        "##{@collapse}",
        class: class_names("panel-collapse-trigger", collapsed_class),
        role: "button",
        data: { toggle: "collapse" },
        aria: { expanded: @open, controls: @collapse }
      ) do
        # heading may contain HTML (e.g., submit buttons, formatted text) that
        # needs to be rendered as HTML, not escaped as text
        # rubocop:disable Rails/OutputSafety
        raw(@heading.html_safe)
        # rubocop:enable Rails/OutputSafety
        span(class: "float-right") { render_collapse_icons }
      end
    end
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

    # link_icon returns HTML strings that need to be rendered as HTML,
    # not escaped as text. Nil check needed as link_icon may return nil
    # in test environments where icon assets aren't available
    # rubocop:disable Rails/OutputSafety
    raw(chevron_down.html_safe) if chevron_down
    raw(chevron_up.html_safe) if chevron_up
    # rubocop:enable Rails/OutputSafety
  end
end
