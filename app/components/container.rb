# frozen_string_literal: true

# Renders a max-width-constrained wrapper element -- `<div>` by default,
# or any other tag via `element:` (the shared layout uses this for its
# one `<main>`). Centralizes the width-symbol -> CSS-class mapping that
# used to live duplicated between `container_class` (`Views::
# FullPageBase::LayoutClasses`, which signals page-level width across
# the layout render boundary via `content_for`) and ~16 call sites that
# hardcoded the same class strings directly for sub-section width limits.
#
# MO's `container-*` classes are custom, fixed pixel-width ceilings, not
# Bootstrap's own `.container`/`.container-fluid` mechanism (Bootstrap's
# is a multi-breakpoint staircase of exact widths, not a single cap) --
# see `app/assets/stylesheets/mo/_layout.scss`. Centralizing the mapping
# here means a future Bootstrap 3->4 container-class migration (#3797)
# only touches WIDTH_CLASSES, not every call site.
#
# @example Basic (a <div>)
#   Container(width: :text) { render_fields }
#
# @example With extra classes/attrs
#   Container(width: :text, class: "ml-4", data: { controller: "foo" }) do
#     render_fields
#   end
#
# @example As the layout's <main>
#   Container(element: :main, id: "content", class: content_classes,
#             data: { controller: "lightgallery" }) { yield }
#
# @example Class-only, for callers that can't render the component
#   directly (e.g. a Components::Table column, or merging into another
#   component's class: arg)
#   t.column(nil, class: Components::Container.class_for(:text)) { ... }
class Components::Container < Components::Base
  WIDTH_CLASSES = {
    text: "container-text",
    text_image: "container-text-image",
    wide: "container-wide",
    full: "container-full"
  }.freeze

  # Dual access, matching Components::Collapsible.collapse_classes --
  # callable directly for string-only callers, and used internally by
  # #width_class below. Any width not in WIDTH_CLASSES (including
  # explicit :full) falls back to "container-full", matching
  # container_class's original case statement.
  def self.class_for(width)
    WIDTH_CLASSES.fetch(width, WIDTH_CLASSES[:full])
  end

  prop :width, _Nilable(Symbol), default: nil
  prop :element, Symbol, default: :div
  # Catch-all for class:, id:, data:, and any other HTML attrs --
  # matches Components::Collapsible/Navbar's pattern.
  prop :attributes, _Hash(Symbol, _Any?), :**

  def view_template(&block)
    send(@element,
         class: class_names(width_class, @attributes[:class]),
         **@attributes.except(:class),
         &block)
  end

  private

  def width_class
    self.class.class_for(@width) if @width
  end
end
