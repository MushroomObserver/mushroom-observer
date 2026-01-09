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
#     panel.with_thumbnail { image("photo.jpg") }
#     panel.with_body { "First section" }
#     panel.with_body { "Second section" }
#     panel.witih_footer { "Footer text" }
#   end)
#
# @example Panel with collapsing body
#   render(Components::Panel.new(
#     collapsible: true,
#     collapse_target: "#hidden"
#   ) do |panel|
#     panel.with_heading { strong { "Title" } }
#     panel.with_thumbnail { image("photo.jpg") }
#     panel.with_body { "First section" }
#     panel.with_body(collapse: true) { "Second section" }
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
#
# @example Panel with unwrapped body (e.g., for list-group)
#   render(Components::Panel.new do |panel|
#     panel.with_heading { "Comments" }
#     panel.with_body(wrapper: false) do
#       ul(class: "list-group") do
#         li(class: "list-group-item") { "Comment 1" }
#         li(class: "list-group-item") { "Comment 2" }
#       end
#     end
#   end)
class Components::Panel < Components::Base
  include Phlex::Slotable

  prop :panel_class, _Nilable(String), default: nil
  prop :panel_id, _Nilable(String), default: nil
  prop :attributes, Hash, default: -> { {} }
  # Set collapsible: :true on component, plus panel.with_body(collapse: true)
  prop :collapsible, _Nilable(_Boolean), default: nil
  # Normally :collapse_target should be an id selector, like "#collapse_target".
  # For multiple collapsing bodies off one trigger, pass a class: ".targets"
  prop :collapse_target, _Nilable(String), default: nil
  prop :collapse_message, _Nilable(String), default: nil
  prop :expanded, _Nilable(_Boolean), default: nil
  # Special for matrix boxes, for Bootstrap 3 "grid" effect via Stimulus:
  # Wrap thumbnail and body in .panel-sizing div, equalized per row.
  # Remove this when migrating to Bootstrap >= 4.
  prop :sizing, _Boolean, default: false

  slot :heading, lambda { |classes: nil, title: true, &content|
    render_heading(classes:, title:, &content)
  }
  slot :heading_links
  slot :thumbnail, lambda { |classes: nil, id: nil, data: nil, &content|
    render_thumbnail(classes:, id:, data:, &content)
  }
  slot :body, lambda { |classes: nil, id: nil, collapse: false, wrapper: true,
                       &content|
    render_body(classes:, collapse:, id:, wrapper:, &content)
  }, collection: true
  slot :footer, lambda { |classes: nil, &content|
    render_footer(classes:, &content)
  }, collection: true

  def view_template
    classes = class_names("panel panel-default", @panel_class)
    define_collapse_target
    div(
      class: classes,
      id: @panel_id,
      **@attributes
    ) do
      render(heading_slot) if heading_slot?
      render_thumbnail_and_body
      footer_slots.each { |slot| render(slot) } if footer_slots?
    end
  end

  def define_collapse_target
    return if @collapse_target.blank?

    if @collapse_target.start_with?("#")
      @collapse_id = @collapse_target[1..]
    elsif @collapse_target.start_with?(".")
      @collapse_class = @collapse_target[1..]
    end
  end

  def render_heading(classes:, title:, &content)
    if title
      classes = classes.presence || "h4 panel-title"
      div(class: "panel-heading") do
        div(class: classes) do
          span(&content)
          whitespace
          render_heading_links if heading_links_slot? || @collapsible
        end
      end
    else
      div(class: class_names("panel-heading", classes)) do
        yield if block_given?
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
      "panel-collapse-trigger ml-3", @expanded ? "" : "collapsed"
    )
    link_to(
      "javascript:void(0)",
      role: :button,
      class: classes,
      data: { toggle: "collapse", target: @collapse_target },
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

  def render_thumbnail_and_body
    # Special .panel-sizing div for matrix boxes, in Bootstrap 3 only
    if @sizing
      div(class: "panel-sizing") { render_middle_sections }
    else
      render_middle_sections
    end
  end

  def render_middle_sections
    render(thumbnail_slot) if thumbnail_slot?
    body_slots.each { |slot| render(slot) } if body_slots?
  end

  def render_thumbnail(classes:, id:, data:, &content)
    # `classes` entirely replaceable here. .thumbnail-container is the default
    classes ||= "thumbnail-container"
    args = { class: classes, id:, data: }.compact
    div(**args, &content)
  end

  def render_body(classes:, id:, collapse:, wrapper:, &content)
    return render_collapse_body(classes:, id:, wrapper:, &content) if collapse

    render_plain_body(classes:, id:, wrapper:, &content)
  end

  def render_plain_body(classes:, id:, wrapper:, &content)
    return yield if wrapper == false

    classes = class_names("panel-body", classes)
    div(class: classes, id:, &content)
  end

  def render_collapse_body(classes:, id:, wrapper:, &content)
    expanded = @expanded ? "in" : nil
    args = {
      class: class_names("panel-collapse collapse", expanded, @collapse_class),
      id: @collapse_id
    }.compact
    div(**args) { render_plain_body(classes:, id:, wrapper:, &content) }
  end

  def render_footer(classes:)
    classes = class_names("panel-footer", classes)
    div(class: classes) do
      yield if block_given?
    end
  end
end
