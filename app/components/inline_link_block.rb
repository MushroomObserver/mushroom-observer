# frozen_string_literal: true

# Renders a group of inline mod/add links -- the observation-show
# sub-panel edit/destroy pairs, the send-question link, sibling
# records, etc. Pure layout glue: a leading non-breaking space plus a
# `white-space: nowrap` wrapper so the group can't be split across a
# line break. It does NOT style the items themselves.
#
# Each item is expected to already carry `ITEM_CLASS`
# (`.inline-icon-link`, MO's own bordered, hover-inverting outline
# style for icon-only inline links -- see `_links_buttons_alerts.scss`)
# on its OWN element -- callers building a `Components::Button`/
# `Components::Link` pass `class: Components::InlineLinkBlock.item_class(
# existing_class)` themselves (merged with any other class the item
# needs, e.g. a per-record destroy-button selector class).
# `Components::InlineCRUDLinks` does this for every item it builds
# internally; a caller assembling its own item (e.g. `extras:`, or a
# hand-rolled affordance outside `InlineCRUDLinks` entirely) is
# responsible for adding the class itself, via the same `item_class`
# helper -- one shared place for the class name + merge logic, even
# though the underlying renderers differ (`Button::ModalToggle`,
# `Button::Delete`, `Link::Icon`, `Link::External` all take a plain
# `class:` kwarg already; nothing about calling them is "hand-rolled").
#
# This component intentionally can't apply that class FOR a caller --
# items arrive as opaque, already-built Phlex instances or SafeBuffer
# strings, so there's no element inside them for this component to
# reach into and restyle after the fact. That's a real
# constraint, not an oversight: making it reachable would mean items
# stop being pre-built instances and become something this component
# constructs itself (plain data -- label/path/icon tuples), which is
# a bigger redesign than this component alone.
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

  def view_template
    return if @items.empty?

    span(class: "text-nowrap") do
      nbsp
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
