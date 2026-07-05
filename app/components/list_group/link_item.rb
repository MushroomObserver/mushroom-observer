# frozen_string_literal: true

# Standalone "linked" list-group-item — for rows where the
# interactive element itself (an `<a>` from `Link(...)`, a
# `<button>` from `Button(...)`) should carry `list-group-item`,
# rather than being wrapped in a separate item container.
# Bootstrap's `.list-group-item` sets its own padding; wrapping an
# `<a>` in it would put the padding on the wrapper and shrink the
# link's own clickable area down to its unpadded content.
#
# Unlike `Components::ListGroup::Item`, this renders no wrapper tag
# of its own — it just yields the composed class string
# (`"list-group-item <extra>"`) to the block, which applies it to
# whatever it renders. That makes it a completely normal nested
# render (no `vanish`, no deferred registration), so it's fully
# compatible with Phlex fragment caching (`cache(...) do ... end`)
# — unlike routing the same row through `ListGroup#link_item`
# inside a `ListGroup(...) do |list| ... end` block, which defers
# rendering until after the block's `cache` wrapper has already
# captured (or skipped) its content.
#
# `ListGroup#link_item` delegates here too, so both the standalone
# and builder-registered paths share one implementation.
#
# No unit test asserts the cache-hit path directly —
# `ComponentTestCase#render` doesn't exercise Phlex's fragment-cache
# internals the same way a real controller render does, so a
# swapped-in `Rails.cache` store never actually gets hit in that
# harness. The compatibility claim rests on this being an ordinary
# nested `render(component, &block)` call, no different in kind from
# `render(Admin.new(...))` / `render(Login.new(...))`, which already
# sit inside `cache(...) do ... end` in
# `Views::Layouts::Sidebar#render_top_section` today.
#
# @example Standalone (e.g. inside a cached fragment)
#   render(Components::ListGroup::LinkItem.new(class: "indent")) do |css_class|
#     Link(type: :active, content: title, path: url, class: css_class)
#   end
class Components::ListGroup::LinkItem < Components::Base
  def initialize(class: nil)
    super()
    @html_class = grab(class:)
  end

  def view_template(&block)
    yield(class_names("list-group-item", @html_class))
  end
end
