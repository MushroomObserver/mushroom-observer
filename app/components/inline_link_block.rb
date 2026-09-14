# frozen_string_literal: true

# Renders a group of inline mod/add links -- the observation-show
# sub-panel edit/destroy pairs, the send-question link, sibling
# records, etc. Layout glue only: a margin on the wrapper
# (`margin_class:`), a leading and between-item non-breaking space,
# and `white-space: nowrap` so the group can't split across a line
# break. The margin lands on the wrapper, not on any item.
#
# Each item must already carry `ITEM_CLASS` (`.inline-icon-link`) on
# its element -- callers build it via `item_class(existing_class)`.
# This component can't apply the class for a caller: items arrive as
# opaque, already-built Phlex instances or strings, with no element
# to reach into.
#
# Renders nothing when `items` is empty.
#
# @example
#   InlineLinkBlock(items: [edit_button, destroy_button])
class Components::InlineLinkBlock < Components::Base
  ITEM_CLASS = "inline-icon-link"

  # Shared class name + merge logic for every item this component
  # renders. A plain method (not `class_names`, which needs a Phlex/
  # ActionView instance context) so it's callable from anywhere that
  # builds an item -- `Components::InlineCRUDLinks` or an external
  # caller assembling its own `Components::Button`/`Link` instance.
  def self.item_class(existing = nil)
    [ITEM_CLASS, existing].compact_blank.join(" ")
  end

  prop :items, _Array(_Union(Phlex::SGML, String))
  prop :margin_class, String, default: "ml-2"

  def view_template
    return if @items.empty?

    span(class: "text-nowrap #{@margin_class}") do
      nbsp
      @items.each_with_index do |item, index|
        nbsp if index.positive?
        render_item(item)
      end
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
