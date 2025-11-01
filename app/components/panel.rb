# frozen_string_literal: true

# Component for rendering Bootstrap panels (cards).
#
# Supports:
# - Basic panels with heading, body, and footer
# - Collapsible panels with open/closed state
# - Multiple panel bodies
# - Custom CSS classes and attributes
#
# @example Basic panel
#   render Components::Panel.new(heading: "Title") do
#     "Panel content"
#   end
#
# @example Panel with footer
#   render Components::Panel.new(
#     heading: "Title",
#     footer: "Footer text"
#   ) do
#     "Panel content"
#   end
#
# @example Collapsible panel
#   render Components::Panel.new(
#     heading: "Click to expand",
#     collapse: "my_panel",
#     open: false
#   ) do
#     "Collapsible content"
#   end
#
# @example Panel with heading links
#   render Components::Panel.new(
#     heading: "Title",
#     heading_links: link_to("Edit", edit_path)
#   ) do
#     "Panel content"
#   end
#
# @example Multiple panel bodies
#   render Components::Panel.new(
#     heading: "Title",
#     panel_bodies: ["First body", "Second body"]
#   )
#
# @example Panel with thumbnail
#   render Components::Panel.new(
#     heading: "Title",
#     thumbnail: image_tag("photo.jpg")
#   ) do
#     "Panel content"
#   end
class Components::Panel < Components::Base
  prop :heading, _Nilable(String), default: nil
  prop :heading_links, _Nilable(String), default: nil
  prop :footer, _Nilable(String), default: nil
  prop :thumbnail, _Nilable(String), default: nil
  prop :panel_class, _Nilable(String), default: nil
  prop :inner_class, _Nilable(String), default: nil
  prop :inner_id, _Nilable(String), default: nil
  prop :collapse, _Nilable(String), default: nil
  prop :collapse_message, _Nilable(String), default: nil
  prop :open, _Boolean, default: false
  prop :panel_bodies, _Nilable(Array), default: nil
  prop :formatted_content, _Boolean, default: false
  prop :attributes, Hash, default: -> { {} }

  def view_template(&block)
    content = block ? capture(&block).to_s : ""

    # If inner_id is provided and there's a heading, put the ID on the outer
    # div so tests can scope to the entire panel including heading links
    panel_id = @inner_id if @heading.present?

    div(
      class: class_names("panel panel-default", @panel_class),
      id: panel_id,
      **@attributes
    ) do
      render_heading if @heading
      render_thumbnail if @thumbnail
      render_body_or_bodies(content)
      render_footer if @footer
    end
  end

  private

  def render_heading
    div(class: "panel-heading") do
      if @collapse.present?
        render_collapsible_heading
      else
        render_static_heading
      end
    end
  end

  def render_static_heading
    h4(class: "panel-title") do
      # heading may contain HTML (e.g., submit buttons, formatted text) that
      # needs to be rendered as HTML, not escaped as text
      # rubocop:disable Rails/OutputSafety
      raw(@heading.html_safe)
      if @heading_links.present?
        # heading_links contains HTML from link_to helper
        # that needs to be rendered as HTML, not escaped as text
        span(class: "float-right") { raw(@heading_links.html_safe) }
      end
      # rubocop:enable Rails/OutputSafety
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

  def render_thumbnail
    # rubocop:disable Rails/OutputSafety
    div(class: "thumbnail-container") { raw(@thumbnail.html_safe) }
    # rubocop:enable Rails/OutputSafety
  end

  def render_body_or_bodies(content)
    if @panel_bodies.present?
      render_multiple_bodies
    elsif @collapse.present?
      render_collapsible_body(content)
    else
      render_single_body(content)
    end
  end

  def render_multiple_bodies
    @panel_bodies.each_with_index do |body_content, idx|
      last_body = idx == @panel_bodies.length - 1

      if @collapse.present? && last_body
        render_collapsible_body(body_content)
      else
        render_single_body(body_content)
      end
    end
  end

  def render_collapsible_body(content)
    div(
      class: class_names("panel-collapse collapse", @open ? "in" : nil),
      id: @collapse
    ) do
      render_single_body(content)
    end
  end

  def render_single_body(content)
    return if content.blank?
    # When formatted_content is true, content contains pre-formatted HTML
    # (e.g., from render calls) that needs to be rendered as HTML, not escaped
    # rubocop:disable Rails/OutputSafety
    return raw(content.html_safe) if @formatted_content
    # rubocop:enable Rails/OutputSafety

    # Only put inner_id on body if there's no heading
    # (otherwise it's on outer div)
    body_id = @heading.present? ? nil : @inner_id

    div(
      class: class_names("panel-body", @inner_class),
      id: body_id
    ) do
      # Content may contain HTML from Rails helpers (e.g., link_to, form
      # elements) that needs to be rendered as HTML, not escaped as text
      # rubocop:disable Rails/OutputSafety
      raw(content.html_safe)
      # rubocop:enable Rails/OutputSafety
    end
  end

  def render_footer
    div(class: "panel-footer") do
      # Footer may contain HTML from Rails helpers (e.g., link_to, buttons)
      # that needs to be rendered as HTML, not escaped as text
      # rubocop:disable Rails/OutputSafety
      raw(@footer.html_safe)
      # rubocop:enable Rails/OutputSafety
    end
  end
end
