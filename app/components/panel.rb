# frozen_string_literal: true

# Component for rendering Bootstrap panels (cards).
#
# Accepts slots for panel subcomponents:
#   heading, heading_links, thumbnail, body, footer
#
# @example Basic panel with heading and body
#   render(Components::Panel.new do |panel|
#     panel.with_heading { "Title" }
#     panel.with_body { "Panel content" }
#   end)
#
# @example Panel with all subcomponents
#   render(Components::Panel.new do |panel|
#     panel.with_heading { strong { "Title" } }
#     panel.with_thumbnail { image_tag("photo.jpg") }
#     panel.with_body { "First section" }
#     panel.with_body { "Second section" }
#     panel.witih_footer { "Footer text" }
#   end)
#
# @example Panel with custom class and ID
#   render(Components::Panel.new(
#     panel_class: "custom-panel",
#     panel_id: "my_panel"
#   ) do |panel|
#     panel.with_body { "Content" }
#   end)
class Components::Panel < Components::Base
  include Phlex::Slotable

  prop :panel_class, _Nilable(String), default: nil
  prop :panel_id, _Nilable(String), default: nil
  prop :attributes, Hash, default: -> { {} }
  prop :collapsible, _Nilable(_Boolean), default: nil
  prop :collapse_id, _Nilable(String), default: nil
  prop :collapse_message, _Nilable(String), default: nil
  prop :expanded, _Nilable(_Boolean), default: nil

  slot :heading, lambda { |classes: nil, &content|
    render_heading(classes:, &content)
  }
  slot :heading_links
  slot :thumbnail
  slot :body, lambda { |classes: nil, collapse: false, &content|
    render_body(classes:, collapse:, &content)
  }, collection: true
  slot :footer

  def view_template
    classes = class_names("panel panel-default", @panel_class)
    div(
      class: classes,
      id: @panel_id,
      **@attributes
    ) do
      # yield if block_given?

      render_thumbnail if thumbnail_slot?
      render(heading_slot) if heading_slot?
      body_slots.each { |slot| render(slot) } if body_slots?
      render_footer if footer_slot?
    end
  end

  def render_heading(classes:)
    classes = classes.presence || "h4 panel-title"

    div(class: "panel-heading") do
      div(class: classes) do
        span { yield if block_given? }
        whitespace
        render_heading_links if heading_links_slot? || @collapsible
      end
    end
  end

  # May contain passed-in links, a collapse trigger, or both
  def render_heading_links
    span(class: "panel-heading-links float-right") do
      render(heading_links_slot) if heading_links_slot?
      render_collapse_icons if @collapsible
    end
  end

  def render_collapse_icons
    classes = class_names(
      "panel-collapse-trigger", @expanded ? "" : "collapsed"
    )
    link_to(
      "##{@collapse_id}",
      class: classes,
      role: "button",
      data: { toggle: "collapse" },
      aria: { expanded: @expanded, controls: @collapse_id }
    ) do
      render_collapse_message

      link_icon(:chevron_down, title: :OPEN.l, class: "active-icon")
      link_icon(:chevron_up, title: :CLOSE.l)
    end
  end

  def render_collapse_message
    return if @collapse_message.blank?

    span(class: "font-weight-normal mr-2") do
      plain(@collapse_message)
    end
  end

  def render_thumbnail
    div(class: "thumbnail-container") do
      render(thumbnail_slot)
    end
  end

  def render_body(classes:, collapse:, &content)
    return render_collapse_body(classes:, &content) if collapse

    render_plain_body(classes:, &content)
  end

  def render_plain_body(classes:)
    classes = class_names("panel-body", classes)
    div(class: classes) do
      yield if block_given?
    end
  end

  def render_collapse_body(classes:, &content)
    wrap_class = class_names("panel-collapse collapse", @expanded ? "in" : nil)
    div(class: wrap_class, id: @collapse_id) do
      render_plain_body(classes:, &content)
    end
  end

  def render_footer
    div(class: "panel-footer") do
      render(footer_slot)
    end
  end
end
