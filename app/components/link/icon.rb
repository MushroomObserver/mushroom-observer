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
class Components::Link::Icon < Components::Base
  LABEL_SHOW_CLASSES = "pl-2 d-none d-sm-inline font-weight-bold"

  CONSUMED_OPTS = [:class, :icon, :icon_class, :show_text,
                   :active_icon, :active_content, :button_to, :confirm].freeze

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
    render(Components::Icon.new(type: icon_type, html_class: icon_class))
    return unless stateful?

    render(Components::Icon.new(
             type: @opts[:active_icon], html_class: icon_active_class
           ))
  end

  def render_labels
    span(class: label_class) { trusted_or_plain(@content) }
    return unless stateful?

    span(class: label_active_class) do
      trusted_or_plain(@opts[:active_content])
    end
  end

  # Content can be a textile-rendered html_safe string (e.g. a name's
  # display_name). `plain` would re-escape; `trusted_html` emits it
  # as-is. Plain Strings go through `plain` so user-typed text is
  # escaped normally.
  def trusted_or_plain(text)
    if text.respond_to?(:html_safe?) && text.html_safe?
      trusted_html(text)
    else
      plain(text)
    end
  end

  def icon_class
    class_names(@opts[:icon_class], "px-2")
  end

  def icon_active_class
    class_names(icon_class, "active-icon")
  end

  def label_class
    @opts[:show_text] ? LABEL_SHOW_CLASSES : "sr-only"
  end

  def label_active_class
    class_names(label_class, "active-label")
  end

  def link_attrs
    # confirm: carries the Turbo confirm-dialog text (e.g. description
    # Clone/Merge/Move). Turbo shows the dialog before following the link.
    base = {
      title: @content,
      class: class_names("icon-link", @opts[:class]),
      data: { toggle: "tooltip", title: @content,
              active_title: @opts[:active_content] }
    }
    base[:data][:turbo_confirm] = @opts[:confirm] if @opts[:confirm]
    base[:role] = "button" if @opts[:button_to]
    base.deep_merge(@opts.except(*CONSUMED_OPTS))
  end

  def render_link_or_button(&block)
    if @opts[:button_to]
      button_to(@path, **link_attrs, &block)
    else
      link_to(@path, **link_attrs, &block)
    end
  end
end
