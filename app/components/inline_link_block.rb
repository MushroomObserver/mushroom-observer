# frozen_string_literal: true

# Renders a group of inline mod/add links -- the observation-show
# sub-panel edit/destroy pairs, the send-question link, sibling
# records, etc. Wraps items in `span.inline-link-block.ml-3`, whose
# `gap` spaces items apart without a trailing margin after the last
# one (a margin baked into every item, including the last, could push
# a lone icon wide enough to wrap when it would otherwise fit inline
# -- see the GPS map link). Renders nothing when `items` is empty.
#
# @example
#   InlineLinkBlock(items: [edit_button, destroy_button])
class Components::InlineLinkBlock < Components::Base
  ITEM_CLASS = "inline-icon-link"

  # A plain method, not `class_names` (needs a Phlex/ActionView
  # instance context) -- callable from `InlineCRUDLinks` or any
  # caller building a custom item.
  def self.item_class(existing = nil)
    [ITEM_CLASS, existing].compact_blank.join(" ")
  end

  prop :items, _Array(_Union(Phlex::SGML, String))

  def view_template
    return if @items.empty?

    span(class: "inline-link-block ml-3") do
      @items.each { |item| render_item(item) }
    end
  end

  private

  def render_item(item)
    if item.is_a?(Phlex::SGML)
      render(item)
    else
      trusted_html(item.to_s)
    end
  end
end
