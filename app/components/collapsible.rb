# frozen_string_literal: true

# Renders a Bootstrap collapse target `<div>`.
#
# Centralises the one Bootstrap 3→4 migration risk: Bootstrap 3 uses the
# class `"in"` for the initially-open state; Bootstrap 4 uses `"show"`.
# Change the `expanded:` branch here when upgrading.
#
# @example Basic (initially closed)
#   Collapsible(id: "my_section") do
#     plain("Hidden content")
#   end
#
# @example Initially open
#   Collapsible(id: "geo", expanded: true) do
#     render_fields
#   end
#
# @example Inside a Panel (adds panel-collapse class)
#   Collapsible(id: "obs_body", expanded: @expanded,
#               panel: true, class: "no-transition") do
#     render_body
#   end
#
# @example With extra Stimulus data attrs
#   Collapsible(
#     id: "obs_geo",
#     expanded: @observation.lat.present?,
#     data: { form_exif_target: "collapseFields" }
#   ) do
#     render_fields
#   end
#
# @example A collapsible `<tbody>` instead of a `<div>`
#   Collapsible(id: "target_subs_1", element: :tbody) do
#     render_sub_rows
#   end
#
# @example Class-only, for callers that can't render the component
#   directly (e.g. inside Components::Table's `vanish`-based body
#   builder -- see Components::Table#body, and
#   projects/locations/tables.rb for a real caller)
#   tab.body(id: collapse_id,
#            class: Components::Collapsible.collapse_classes) do
#     render_sub_rows
#   end
class Components::Collapsible < Components::Base
  # `module_function`-style dual access, matching
  # `Components::Button::Styling`'s `btn_class`/`size_class`: callable
  # as `Components::Collapsible.collapse_classes(...)` for callers that
  # only need the class string (e.g. builder/registration code that
  # runs before the component itself could render), and as a private
  # instance method for `view_template` below. Named `html_class:` here
  # (not `class:`) since a bare `class:` keyword parameter on a plain
  # method needs the same reserved-word workaround `grab` solves for
  # instance methods, which isn't available in a class method.
  def self.collapse_classes(expanded: nil, panel: false, html_class: nil)
    [
      "collapse",
      ("in" if expanded), # Bootstrap 4: change "in" → "show"
      ("panel-collapse" if panel),
      html_class
    ].compact_blank.join(" ")
  end

  prop :id, _Nilable(String), default: nil
  prop :expanded, _Nilable(_Boolean), default: nil
  prop :panel, _Boolean, default: false
  prop :element, Symbol, default: :div
  # Catch-all for class:, data:, aria:, and any other HTML attrs --
  # matches Components::Navbar's pattern (plain `class:` in, no
  # separate `html_class:` prop needed). `_Any?`, not bare `_Any` --
  # Literal's `_Any` excludes `NilClass`, so a caller passing an
  # explicit `key: nil` (not just omitting the key) would otherwise
  # raise a Literal::TypeError.
  prop :attributes, _Hash(Symbol, _Any?), :**

  def view_template(&block)
    # `:id` never lands in @attributes -- the explicit `id:` prop above
    # always claims that keyword before the `:**` catch-all sees it.
    send(@element,
         id: @id,
         class: collapse_classes,
         **@attributes.except(:class),
         &block)
  end

  private

  def collapse_classes
    self.class.collapse_classes(expanded: @expanded, panel: @panel,
                                html_class: @attributes[:class])
  end
end
