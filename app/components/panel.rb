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
    PanelHeading(
      heading: @heading,
      heading_links: @heading_links,
      collapse: @collapse,
      collapse_message: @collapse_message,
      open: @open
    )
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

    PanelBody(
      content: content,
      inner_class: @inner_class,
      inner_id: body_id
    )
  end

  def render_footer
    PanelFooter(footer: @footer)
  end
end
