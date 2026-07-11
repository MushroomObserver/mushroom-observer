# frozen_string_literal: true

# Anchor / button styled as an icon-with-label link. The label is
# visually hidden by default (sr-only) but available as both the
# tooltip and an accessible name. Optionally renders with a swappable
# "active" icon + label pair driven by JS state — used by
# bookmark-style toggles where the same target switches appearance.
#
# @example Plain icon link
#   render(Components::Link::Icon.new(content: "Edit",
#                                     path: edit_path(@obj),
#                                     icon: :edit))
#
# @example Show the text alongside the icon
#   render(Components::Link::Icon.new(content: "Delete", path: path,
#                                     icon: :delete, show_text: true))
#
# @example State-swap (active icon + label)
#   render(Components::Link::Icon.new(content: "Subscribe",
#                                     path: subscribe_path,
#                                     icon: :bullhorn,
#                                     active_icon: :check,
#                                     active_content: "Subscribed"))
#
# @example Render as button_to (POSTs instead of GETs)
#   render(Components::Link::Icon.new(content: "Delete", path: path,
#                                     icon: :delete, button_to: true,
#                                     data: { method: :delete }))
#
# @example From a Tab PORO (shortcut)
#   render(Components::Link::Icon.new(tab: Tab::Name::Edit.new(name: @name)))
#
# @example Framed as a Bootstrap button (e.g. a navbar icon-button)
#   render(Components::Link::Icon.new(content: "Prev", path: prev_path,
#                                     icon: :prev, button: :link,
#                                     size: :lg))
class Components::Link::Icon < Components::Base
  include Components::IconLabel
  include Components::Button::Styling

  CONSUMED_OPTS = [:class, :icon, :icon_class, :show_text,
                   :active_icon, :active_content, :button_to, :confirm,
                   :button, :size].freeze

  attr_reader :content, :path, :opts

  def initialize(content: nil, path: nil, tab: nil, **opts)
    super()
    if tab
      @content = tab.title
      @path = tab.path
      @opts = tab.html_options.merge(opts)
    else
      @content = content
      @path = path
      @opts = opts
    end
    validate_no_btn_classes!(@opts[:class])
  end

  def view_template
    return unless @content

    if icon_type.blank?
      render_link_or_button { trusted_or_plain(@content) }
    else
      render_link_or_button { render_inner }
    end
  end

  private

  def icon_type
    @opts[:icon]
  end

  def stateful?
    @opts[:active_icon] && @opts[:active_content]
  end

  # Output order: icon, active_icon (if stateful), label,
  # active_label (if stateful).
  def render_inner
    render_icons
    render_labels
  end

  def render_icons
    render_icon_glyph(icon_type, html_class: icon_class)
    return unless stateful?

    render_icon_glyph(@opts[:active_icon], html_class: icon_active_class)
  end

  def render_labels
    render_icon_label(@content, show_text: @opts[:show_text])
    return unless stateful?

    render_icon_label(@opts[:active_content], show_text: @opts[:show_text],
                                              extra_class: "active-label")
  end

  def icon_class
    class_names(@opts[:icon_class], "px-2")
  end

  def icon_active_class
    class_names(icon_class, "active-icon")
  end

  def link_attrs
    # confirm: carries the Turbo confirm-dialog text (e.g. description
    # Clone/Merge/Move). Turbo shows the dialog before following the link.
    base = {
      title: @content,
      class: class_names("icon-link", button_classes, @opts[:class]),
      data: { toggle: "tooltip", title: @content,
              active_title: @opts[:active_content] }
    }
    base[:data][:turbo_confirm] = @opts[:confirm] if @opts[:confirm]
    base[:role] = "button" if @opts[:button_to]
    base.deep_merge(@opts.except(*CONSUMED_OPTS))
  end

  # `size:` only ever makes sense alongside real btn framing — a
  # dangling `btn-lg` with no `.btn` base class isn't valid Bootstrap
  # markup — so it's computed here, gated on `btn_styling` being
  # present, rather than appended unconditionally in `link_attrs`.
  def button_classes
    styling = btn_styling
    return nil unless styling

    class_names(styling, size_class(@opts[:size]))
  end

  # `nil` (button: omitted) means "plain link" — no btn framing at all,
  # matching Components::Link#btn_styling's semantics so callers can't
  # tell the two Link subclasses apart by behavior. `btn_class` itself
  # treats `:default` as a synonym for nil ("btn-default"), so no
  # separate branch is needed here for that case.
  def btn_styling
    button = @opts[:button]
    return nil unless button
    return nil if button == :strip

    class_names("btn", btn_class(button))
  end

  def render_link_or_button(&block)
    if @opts[:button_to]
      button_to(@path, **link_attrs, &block)
    else
      link_to(@path, **link_attrs, &block)
    end
  end
end
