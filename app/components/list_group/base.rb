# frozen_string_literal: true

# Bootstrap `list-group` container with per-item children.
#
# Iteration-friendly builder pattern: the block yields a `list`
# builder; call `list.item(...) { ... }` once per row, in order.
#
# Three Bootstrap patterns covered:
#
# - **Plain bordered list** (default): rendered as
#   `<div class="list-group">` with each item a
#   `<div class="list-group-item">`.
# - **Flush** (`flush: true`): adds `list-group-flush` so the list
#   has no outer border / radius — used when the list sits inside
#   a `Components::Panel` body.
# - **Semantic `<ul>`** (`element: :ul`): renders `<ul
#   class="list-group">` with each item as `<li class="list-group-
#   item">`. Use when the list is semantically a sequence of
#   items rather than a div-stack.
#
# ## Empty-state placeholder (optional)
#
# Call `list.empty { ... }` to register placeholder content. When
# registered, it's rendered as a trailing
# `<div class="list-group-item none-yet">` after the real items.
# The `.list-group-item.none-yet` CSS rule in `_utilities.scss`
# hides the placeholder unless it's the `:only-child` of its
# list-group, so it shows iff no real rows exist. This works
# seamlessly with Turbo Stream `append` / `remove` actions: the
# broadcast only ever touches the regular
# `<div class="list-group-item">` children, and CSS decides
# whether the placeholder is visible. Don't conditional-render
# the placeholder yourself.
#
# Skip `list.empty` entirely when the list never needs a "no
# items" message — e.g. lists that are guaranteed non-empty at
# render time, or streamed-in lists where the empty case is
# handled elsewhere.
#
# @example Plain iteration with empty placeholder
#   render(Components::ListGroup::Base.new(
#            id: "comments", flush: true
#          )) do |list|
#     @comments.each do |c|
#       list.item(id: dom_id(c)) { render(Comment.new(comment: c)) }
#     end
#     list.empty { :show_comments_no_comments_yet.t }
#   end
#
# @example Flush variant inside a panel
#   render(Components::Panel.new) do |panel|
#     panel.with_body(wrapper: false) do
#       render(Components::ListGroup::Base.new(flush: true)) do |list|
#         @items.each { |i| list.item { plain(i) } }
#       end
#     end
#   end
class Components::ListGroup::Base < Components::Base
  # @param id [String] `id=` for the container element. Use to make
  #   the container a Turbo Stream target.
  # @param flush [Boolean] add `list-group-flush` for borderless
  #   nesting inside a Panel body. Defaults to false.
  # @param element [Symbol] container element — `:div` (default) or
  #   `:ul`. Items take the matching child element (`:div` → `<div>`,
  #   `:ul` → `<li>`).
  # @param class [String] CSS classes appended to the default
  #   `list-group` (+ `list-group-flush` when `flush: true`).
  # @param attributes [Hash] arbitrary HTML attrs forwarded to the
  #   container element (`data:` for Stimulus, ARIA, etc.).
  def initialize(id: nil, flush: false, element: :div,
                 class: nil, attributes: {})
    super()
    @html_id = id
    @flush = flush
    @element = element
    @html_class = grab(class:)
    @attributes = attributes
    @items = []
    @empty_block = nil
  end

  def view_template(&block)
    # Phlex `vanish` pattern: invoke the caller's block to collect
    # `item(...)` + `empty { ... }` registrations without writing
    # anything to the output buffer; render the container + items
    # afterwards.
    vanish(self, &block)

    send(@element, **container_attrs) do
      @items.each { |i| render_item(i) }
      render_empty if @empty_block
    end
  end

  # Register one list-group-item. Block is rendered later as the
  # item's content. Caller-supplied `class:` / `id:` / arbitrary
  # attrs flow onto the item element.
  #
  # @return [nil] so the call doesn't accidentally emit anything
  def item(class: nil, id: nil, **attrs, &block)
    @items << {
      class: grab(class:),
      id: id,
      attrs: attrs,
      block: block
    }
    nil
  end

  # Register the empty-state placeholder. Always rendered after the
  # real items, wrapped in `<div class="list-group-item none-yet">`.
  # CSS hides it unless it's the only `.list-group-item` child —
  # see the class-level docs.
  #
  # @return [nil]
  def empty(&block)
    @empty_block = block
    nil
  end

  private

  def container_attrs
    classes = class_names(
      "list-group", ("list-group-flush" if @flush), @html_class
    )
    { class: classes, id: @html_id }.compact.merge(@attributes)
  end

  def item_element
    @element == :ul ? :li : :div
  end

  def render_item(item)
    render(Components::ListGroup::Item.new(
             element: item_element, class: item[:class],
             id: item[:id], attributes: item[:attrs]
           ), &item[:block])
  end

  def render_empty
    render(Components::ListGroup::Item.new(
             element: item_element, class: "none-yet"
           ), &@empty_block)
  end
end
