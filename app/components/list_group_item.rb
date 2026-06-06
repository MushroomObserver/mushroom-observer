# frozen_string_literal: true

# One Bootstrap `list-group-item` row. Used by `Components::ListGroup`
# for each item registered via `list.item(...)`, and rendered
# directly elsewhere (notably the `Comment` model's
# `after_create_commit` broadcast, which prepends a new comment row
# into the comments-for-object list group).
#
# Rendering it as a standalone component (rather than ListGroup
# emitting the wrapper inline) lets a Turbo Stream `prepend`
# broadcast a self-contained `.list-group-item.comment#comment_<id>`
# wrapper while a sibling `broadcast_update_to(target: "comment_<id>")`
# updates only the inner content — both code paths point at the same
# wrapper shape from one definition.
#
# @example Container element follows the parent list-group
#   render(Components::ListGroupItem.new(element: :li,
#                                        class: "comment",
#                                        id: "comment_42")) do
#     # inner content (e.g. a CommentItem view)
#   end
class Components::ListGroupItem < Components::Base
  # @param element [Symbol] `:div` (default, matches `<div class="list-group">`)
  #   or `:li` (matches `<ul class="list-group">`).
  # @param class [String] appended to the default `list-group-item`.
  #   Falsy values are skipped.
  # @param id [String, nil] `id=` attribute. Required for Turbo Stream
  #   `update` / `replace` / `remove` targets to find the row.
  # @param attributes [Hash] arbitrary HTML attrs (data:, aria-*, etc.).
  def initialize(element: :div, class: nil, id: nil, attributes: {})
    super()
    @element = element
    @html_class = binding.local_variable_get(:class)
    @html_id = id
    @attributes = attributes
  end

  def view_template(&block)
    send(@element,
         class: class_names("list-group-item", @html_class),
         id: @html_id,
         **@attributes,
         &block)
  end
end
