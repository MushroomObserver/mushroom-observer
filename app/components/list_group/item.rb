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
#   render(Components::ListGroup::Item.new(element: :li,
#                                        class: "comment",
#                                        id: "comment_42")) do
#     # inner content (e.g. a CommentItem view)
#   end
class Components::ListGroup::Item < Components::Base
  # `:div` (default, matches `<div class="list-group">`) or `:li`
  # (matches `<ul class="list-group">`).
  prop :element, _Union(:div, :li), default: :div
  # `id=` attribute. Required for Turbo Stream `update` / `replace` /
  # `remove` targets to find the row.
  prop :id, _Nilable(String), default: nil
  # Catch-all for class:, data:, aria:, and any other HTML attrs --
  # matches Icon/Collapsible's pattern. `class:` is appended to the
  # default `list-group-item`.
  prop :attributes, _Hash(Symbol, _Any?), :**

  def view_template(&block)
    send(@element,
         class: class_names("list-group-item", @attributes[:class]),
         id: @id,
         **@attributes.except(:class),
         &block)
  end
end
