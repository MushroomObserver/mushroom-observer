# frozen_string_literal: true

# Component for rendering a Bootstrap 4 card (`.card`/`.card-header`/
# `.card-body`/`.card-footer`). The prop/method names still say "panel"
# throughout (`panel_class:`, `panel_id:`, `Panel(...)`) — that naming
# is this component's identity, independent of the emitted CSS class.
#
# Accepts slots for panel subcomponents:
#   heading, heading_links, thumbnail, body, footer
#
# @example Basic panel with heading and body
#   Panel do |panel|
#     panel.with_heading { "Title" }
#     panel.with_body { "Panel content" }
#   end
#
# @example Panel with all subcomponents
#   Panel do |panel|
#     panel.with_heading { strong { "Title" } }
#     panel.with_thumbnail { image("photo.jpg") }
#     panel.with_body { "First section" }
#     panel.with_body { "Second section" }
#     panel.with_footer { "Footer text" }
#   end
#
# @example Panel with collapsing body
#   Panel(
#     collapsible: true,
#     collapse_target: "#hidden"
#   ) do |panel|
#     panel.with_heading { strong { "Title" } }
#     panel.with_thumbnail { image("photo.jpg") }
#     panel.with_body { "First section" }
#     panel.with_body(collapse: true) { "Second section" }
#     panel.with_footer { "Footer text" }
#   end
#
# @example Panel with custom class and ID
#   Panel(
#     panel_class: "custom-panel",
#     panel_id: "my_panel"
#   ) do |panel|
#     panel.with_body { "Content" }
#   end
#
# @example Panel with unwrapped body (e.g., for list-group)
#   Panel do |panel|
#     panel.with_heading { "Comments" }
#     panel.with_body(wrapper: false) do
#       ul(class: "list-group") do
#         li(class: "list-group-item") { "Comment 1" }
#         li(class: "list-group-item") { "Comment 2" }
#       end
#     end
#   end
class Components::Panel < Components::Base
  include Phlex::Slotable

  prop :panel_class, _Nilable(String), default: nil
  prop :panel_id, _Nilable(String), default: nil
  prop :attributes, _Hash(Symbol, _Any), default: -> { {} }
  # Set collapsible: :true on component, plus panel.with_body(collapse: true)
  prop :collapsible, _Nilable(_Boolean), default: nil
  # Normally :collapse_target should be an id selector, like "#collapse_target".
  # For multiple collapsing bodies off one trigger, pass a class: ".targets"
  prop :collapse_target, _Nilable(String), default: nil
  prop :collapse_message, _Nilable(String), default: nil
  prop :expanded, _Nilable(_Boolean), default: nil

  slot :heading, lambda { |classes: nil, title: true, &content|
    render_heading(classes:, title:, &content)
  }
  slot :heading_links
  slot :thumbnail, lambda { |classes: nil, id: nil, data: nil, &content|
    render_thumbnail(classes:, id:, data:, &content)
  }
  slot :body, lambda { |classes: nil, id: nil, data: nil, collapse: false,
                       wrapper: true, &content|
    render_body(classes:, collapse:, id:, data:, wrapper:, &content)
  }, collection: true
  slot :footer, lambda { |classes: nil, &content|
    render_footer(classes:, &content)
  }, collection: true

  # `h-100` (passed via `panel_class:`) needs the card to be a
  # distinct child of the stretched flex item, not the stretched item
  # itself -- `height: 100%` on the same element being stretched by
  # `align-items: stretch` doesn't resolve the way it does against a
  # parent with a definite height. `Components::Grid::Box` wraps this
  # card in a separate `<li>` for that reason -- don't collapse them
  # into one element.
  def view_template
    classes = class_names("card", @panel_class)
    define_collapse_target
    div(
      class: classes,
      id: @panel_id,
      **@attributes
    ) do
      render(heading_slot) if heading_slot?
      render_middle_sections
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
      classes = classes.presence || "h4 card-title"
      div(class: "card-header") do
        div(class: classes) do
          span(&content)
          whitespace
          render_heading_links if heading_links_slot? || @collapsible
        end
      end
    else
      div(class: class_names("card-header", classes)) do
        yield if block_given?
      end
    end
  end

  # May contain passed-in links, a collapse trigger, or both
  def render_heading_links
    span(class: "card-header-links float-right") do
      render(heading_links_slot) if heading_links_slot?
      render_collapse_icons if @collapsible
    end
  end

  def render_collapse_icons
    Link(type: :collapse_toggle,
         target_id: @collapse_id || "",
         collapsed: !@expanded,
         class: "panel-collapse-trigger ml-3",
         data: collapse_toggle_data,
         aria: collapse_aria) do
      render_collapse_message

      Icon(type: :chevron_down, title: :open.ti, class: "active-icon")
      Icon(type: :chevron_up, title: :close.ti)
    end
  end

  # For ID-based targets, omit data-target so Bootstrap reads href="#id"
  # and calls e.preventDefault() — preventing Turbo from navigating the
  # frame. For CSS class selectors (rare, never inside Turbo frames),
  # data-target is required so Bootstrap can match multiple panes.
  def collapse_toggle_data
    @collapse_class ? { target: @collapse_target } : {}
  end

  def collapse_aria
    aria = { expanded: @expanded ? "true" : "false" }
    aria[:controls] = @collapse_id if @collapse_id.present?
    aria
  end

  def render_collapse_message
    return if @collapse_message.blank?

    span(class: "font-weight-normal mr-2") do
      plain(@collapse_message)
    end
  end

  def render_middle_sections
    render(thumbnail_slot) if thumbnail_slot?
    body_slots.each { |slot| render(slot) } if body_slots?
  end

  def render_thumbnail(classes:, id:, data:, &content)
    # `classes` entirely replaceable here. `card-img-top` rounds this
    # div's top corners to match the card (BS4 -- see
    # mo/_images.scss's matching `overflow: hidden` on
    # `.thumbnail-container`, needed since the contained <img> itself
    # isn't rounded).
    classes ||= "thumbnail-container card-img-top"
    args = { class: classes, id:, data: }.compact
    div(**args, &content)
  end

  def render_body(classes:, id:, data:, collapse:, wrapper:, &content)
    if collapse
      return render_collapse_body(classes:, id:, data:, wrapper:, &content)
    end

    render_plain_body(classes:, id:, data:, wrapper:, &content)
  end

  def render_plain_body(classes:, id:, data:, wrapper:, &content)
    return yield if wrapper == false

    classes = class_names("card-body", classes)
    div(class: classes, id:, data:, &content)
  end

  def render_collapse_body(classes:, id:, data:, wrapper:, &content)
    Collapsible(
      id: @collapse_id,
      expanded: @expanded,
      panel: true,
      class: @collapse_class
    ) { render_plain_body(classes:, id:, data:, wrapper:, &content) }
  end

  def render_footer(classes:)
    classes = class_names("card-footer", classes)
    div(class: classes) do
      yield if block_given?
    end
  end
end
