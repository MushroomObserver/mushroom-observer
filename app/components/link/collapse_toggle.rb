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
# When the trigger also needs a navigation fallback for no-JS (e.g. a
# "+ New" link that opens an inline form with JS but falls back to
# the standalone create page without), pass `fallback_href:`. The
# component uses that URL as `href` and adds `data-target` explicitly
# so Bootstrap still finds the collapse pane (Bootstrap reads
# `data-target` before `href`). It also wires up the
# `collapse-fallback` Stimulus controller to prevent the default
# navigation -- Bootstrap 3's collapse data-API only does that itself
# when `data-target` is absent, so with `fallback_href:` (which
# requires `data-target`) it doesn't. This is a Bootstrap 3
# workaround; re-check whether it's still needed when MO migrates to
# Bootstrap 4/5 (issue #3797) -- collapse.js's data-API may behave
# differently there.
#
# Pass `button:` for Bootstrap button styling (e.g. `:link`,
# `:outline`) and `size:` for size modifiers (e.g. `:xs`, `:sm`).
#
# @example icon kwarg toggle (starts closed)
#   render(Components::Link::CollapseToggle.new(
#     target_id: "contribution_legend",
#     icon: :info_circle,
#     button: :link,
#     size: :xs
#   ))
#
# @example icon + closed text with no-JS fallback (starts closed)
#   render(Components::Link::CollapseToggle.new(
#     target_id: "new_form_container",
#     fallback_href: new_thing_path,
#     closed_text: :create.ti
#   ))
#
# @example block form (block wins over kwargs)
#   render(Components::Link::CollapseToggle.new(
#     target_id: "sub_rows_42", class: "panel-collapse-trigger",
#     collapsed: true
#   )) { render(Components::Icon.new(type: :chevron_down)) }
class Components::Link::CollapseToggle < Components::Link
  include Components::Button::CollapseContent

  prop :target_id, String
  prop :collapsed, _Boolean, default: true
  prop :fallback_href, _Nilable(String), default: nil
  prop :size, _Nilable(_Union(*Components::Button::SIZES)), default: nil
  prop :icon, _Nilable(_Union(*Components::Button::ICONS)), default: nil
  prop :icon_class, _Nilable(String), default: nil
  prop :icon_title, _Nilable(String), default: nil
  prop :open_text, _Nilable(String), default: nil
  prop :closed_text, _Nilable(String), default: nil
  prop :attributes, _Hash(Symbol, _Any?), :**

  def initialize(target_id:, collapsed: true, fallback_href: nil,
                 size: nil, **opts)
    icon        = opts.delete(:icon)
    icon_class  = opts.delete(:icon_class)
    icon_title  = opts.delete(:icon_title)
    open_text   = opts.delete(:open_text)
    closed_text = opts.delete(:closed_text)
    button      = opts.delete(:button)
    super(target_id: target_id, collapsed: collapsed,
          fallback_href: fallback_href, size: size, icon: icon,
          icon_class: icon_class, icon_title: icon_title,
          open_text: open_text, closed_text: closed_text,
          button: button, **opts)
  end

  def view_template(&block)
    a(
      href: link_href,
      role: "button",
      class: class_names(btn_styling, size_class, @attributes[:class],
                         { "collapsed" => @collapsed }),
      data: { toggle: "collapse", **collapse_data },
      aria: { expanded: @collapsed ? "false" : "true",
              **(@target_id.present? ? { controls: @target_id } : {}) },
      **@attributes.except(:class, :data, :aria)
    ) do
      block ? yield : collapse_content
    end
  end

  private

  def link_href
    @fallback_href || "##{@target_id}"
  end

  def collapse_data
    extra_data = @attributes[:data] || {}
    return extra_data unless @fallback_href

    # Bootstrap's collapse data-API only prevents the default
    # navigation when data-target is absent; fallback_href needs
    # data-target present so collapse.js can find the pane, so the
    # navigation has to be prevented explicitly instead. See
    # app/javascript/controllers/collapse-fallback_controller.js --
    # no :prevent action modifier here, the controller itself decides
    # whether to call preventDefault() (it skips it for a
    # data-turbo-frame trigger, letting Turbo handle that case).
    extra_data.merge(target: "##{@target_id}",
                     controller: [extra_data[:controller],
                                  "collapse-fallback"].compact.join(" "),
                     action: [extra_data[:action],
                              "click->collapse-fallback#intercept"].
                             compact.join(" "))
  end

  def size_class
    Components::Button::Styling.size_class(@size)
  end
end
