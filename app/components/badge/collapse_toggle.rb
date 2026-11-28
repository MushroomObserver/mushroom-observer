# frozen_string_literal: true

# Badge-styled accordion trigger -- an `<a>` collapse toggle (same
# `data-toggle="collapse"`/`fallback_href` mechanics as
# `Components::Link::CollapseToggle`) rendered with `.badge-id` classes
# instead of button/link styling. `value:` is the closed-state label;
# `open_text:` (default "hide") swaps in once the pane is expanded, via
# the same `.collapse-toggle-open`/`.collapse-toggle-closed` CSS
# `Components::Button::CollapseContent` uses.
#
# @example "Shared with: [MCP]" accordion trigger
#   Badge(type: :collapse_toggle, value: "MCP",
#         target_id: "pane_123", fallback_href: external_link_path(123),
#         size: :xl, class: "ml-2 text-uppercase")
class Components::Badge::CollapseToggle < Components::Badge
  include Components::CollapseAnchorAttributes

  prop :value, String
  prop :open_text, String, default: -> { :hide.ti }
  prop :target_id, String
  prop :collapsed, _Boolean, default: true
  prop :fallback_href, _Nilable(String), default: nil
  prop :size, _Union(*Components::Badge::SIZES)
  prop :attributes, _Hash(Symbol, _Any?), :**

  def view_template
    a(href: link_href, role: "button",
      **mix({ class: badge_class }, @attributes.except(:data, :aria)),
      data: { toggle: "collapse", **collapse_data },
      aria: collapse_aria) do
      span(class: "collapse-toggle-open") { plain(@open_text) }
      span(class: "collapse-toggle-closed") { plain(@value) }
    end
  end

  private

  def badge_class
    class_names("badge badge-id", Components::Badge.size_class(@size),
                "collapsed" => @collapsed)
  end
end
