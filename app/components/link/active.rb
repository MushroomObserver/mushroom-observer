# frozen_string_literal: true

# Anchor wired up to the `nav-active` Stimulus controller. When the
# controller detects the current page URL matches this link, it adds
# `.active` to the anchor — used by the sidebar / top-nav to
# highlight which nav item the user is currently on. Allows nav
# fragments to be cached and reused across pages.
#
# Caller-supplied `data:` is deep-merged onto the nav-active wiring,
# so callers can add data attrs without overriding the Stimulus
# target/action attrs.
#
# Pass `icon:` for an icon-only treatment -- `content:` becomes the
# sr-only label and hover tooltip instead of visible text, same as
# `Link::Get`/`Link::External`.
#
# @example
#   render(Components::Link::Active.new(content: "Latest",
#                                       path: observations_path))
class Components::Link::Active < Components::Link
  prop :content, _Nilable(String), default: nil
  prop :path, String
  prop :icon, _Nilable(_Union(*Components::Button::ICONS)), default: nil
  prop :attributes, _Hash(Symbol, _Any?), :**

  def initialize(content: nil, icon: nil, **)
    validate_icon_has_label!(icon, content)
    super
  end

  def view_template
    link_to(@path, **link_args) { render_link_content }
  end

  private

  # Icon-only rendering has no visible text, so content: is the only
  # accessible label it gets (sr-only span + hover tooltip) -- an
  # icon with no content would render with neither.
  def validate_icon_has_label!(icon, content)
    return unless icon && content.blank?

    raise(ArgumentError.new(
            "#{self.class} needs content: when icon: is given -- " \
            "it becomes the icon's only accessible label."
          ))
  end

  def render_link_content
    if @icon
      render_icon_with_text(@icon, @content, show_label: @show_label)
    else
      trusted_or_plain(@content)
    end
  end

  def link_args
    base = { class: class_names(icon_wrapper_class, @attributes[:class]) }
    base = base.deep_merge(tooltip_data) if @icon
    base.deep_merge(@attributes.except(:class)).
      deep_merge(data: nav_active_data)
  end

  def tooltip_data
    { title: @content, data: { tooltip_target: "tip", placement: "top" } }
  end

  def nav_active_data
    { nav_active_target: "link", action: "nav-active#navigate" }
  end
end
