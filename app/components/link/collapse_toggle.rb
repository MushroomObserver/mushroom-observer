# frozen_string_literal: true

# Bootstrap 3 collapse-trigger `<a>`. Renders an `href="#target_id"`
# link with `data-toggle="collapse"` and the matching ARIA attrs.
# The default `collapsed: true` adds the `.collapsed` class (Bootstrap uses
# this to flip chevron icons via CSS when the pane is hidden). Pass
# `collapsed: false` when the target pane starts open (e.g. a cancel button
# shown inside an already-expanded accordion pane).
#
# Accepts `icon:`, `icon_title:`, `open_text:`, `closed_text:` kwargs
# for content when no block is given. The icon title defaults to the
# toggle text when not explicitly supplied.
#
# When the trigger also needs a real navigation fallback for no-JS
# (e.g. a "+ New" link that opens an inline form with JS but falls
# back to the standalone create page without), pass `fallback_href:`.
# The component uses that URL as `href` and adds `data-target`
# explicitly so Bootstrap still finds the collapse pane (Bootstrap
# reads `data-target` before `href`).
#
# Pass `button:` for Bootstrap button styling (e.g. `:btn_link`,
# `:outline`) and `size:` for size modifiers (e.g. `:xs`, `:sm`).
#
# @example icon kwarg toggle (starts closed)
#   render(Components::Link::CollapseToggle.new(
#     target_id: "contribution_legend",
#     icon: :info_circle,
#     button: :btn_link,
#     size: :xs
#   ))
#
# @example icon + closed text with no-JS fallback (starts closed)
#   render(Components::Link::CollapseToggle.new(
#     target_id: "new_form_container",
#     fallback_href: new_thing_path,
#     closed_text: :CREATE.l
#   ))
#
# @example block form (block wins over kwargs)
#   render(Components::Link::CollapseToggle.new(
#     target_id: "sub_rows_42", class: "panel-collapse-trigger",
#     collapsed: true
#   )) { render(Components::Icon.new(type: :chevron_down)) }
class Components::Link::CollapseToggle < Components::Link
  include Components::Button::CollapseContent

  def initialize(target_id:, collapsed: true, fallback_href: nil,
                 size: nil, **opts)
    @target_id     = target_id
    @collapsed     = collapsed
    @fallback_href = fallback_href
    @size          = size
    @icon          = opts.delete(:icon)
    @icon_class    = opts.delete(:icon_class)
    @icon_title    = opts.delete(:icon_title)
    @open_text     = opts.delete(:open_text)
    @closed_text   = opts.delete(:closed_text)
    @html_class    = opts.delete(:class)
    @extra_data    = opts.delete(:data) || {}
    opts.delete(:aria)
    button         = opts.delete(:button)
    @html_attrs    = opts
    super(button: button)
  end

  def view_template(&block)
    a(
      href: link_href,
      role: "button",
      class: class_names(btn_styling, size_class, @html_class,
                         { "collapsed" => @collapsed }),
      data: { toggle: "collapse", **collapse_data },
      aria: { expanded: @collapsed ? "false" : "true",
              **(@target_id.present? ? { controls: @target_id } : {}) },
      **@html_attrs
    ) do
      block ? yield : collapse_content
    end
  end

  private

  def link_href
    @fallback_href || "##{@target_id}"
  end

  def collapse_data
    return @extra_data unless @fallback_href

    @extra_data.merge(target: "##{@target_id}")
  end

  def size_class
    Components::Button::Styling.size_class(@size)
  end
end
