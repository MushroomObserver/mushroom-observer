# frozen_string_literal: true

# Renders a Bootstrap grid column `<div>`, composing `col-{bp}-N` classes
# from breakpoint-keyed width kwargs instead of scattering literal
# `"col-sm-6 col-md-4"` strings -- or the old fixed-shape `Grid::` constants
# -- across every caller. All values are Bootstrap 3 syntax
# (`col-xs-N`/`col-xs-offset-N`); migrating to Bootstrap 4 (`col-N`/
# `offset-N`) touches this one mapping, not every call site.
#
# @example A responsive half/half split
#   Column(sm: 6) { render_left }
#   Column(sm: 6) { render_right }
#
# @example Full width on mobile, offset-centered from sm+
#   Column(xs: 4, offset_xs: 4, class: "text-center") { render_compass }
#
# @example Bootstrap 4-style auto column plus a breakpoint override
#   Column(col: true, sm: 4) { render_name_cell }
#
# @example A non-div element (matches Components::Container's :main case)
#   Column(element: :nav, xs: 8, sm: 2, id: "sidebar") { render_nav }
#
# @example Hidden on xs, visible from sm up (replaces BS3 `.hidden-xs`)
#   Column(sm: 6, hide_at: :xs, show_at: :sm) { render_desktop_only }
#
# @example Visible on xs only, hidden from sm up
#   Column(show_at: :xs, hide_at: :sm) { render_mobile_only }
class Components::Column < Components::Base
  BREAKPOINTS = [:xs, :sm, :md, :lg, :xl].freeze

  # Callable without instantiating -- for call sites that need a raw class
  # string merged into an existing element's `class:` rather than a full
  # Column-wrapped element (Components::Matrix::Box's `columns:` prop
  # default, Views::Layouts::Header#title_cols).
  def self.classes_for(col: false, offset_xs: nil, show_at: nil, hide_at: nil,
                       **widths)
    [
      ("col" if col),
      *BREAKPOINTS.filter_map { |bp| "col-#{bp}-#{widths[bp]}" if widths[bp] },
      ("col-xs-offset-#{offset_xs}" if offset_xs),
      *visibility_classes(show_at: show_at, hide_at: hide_at)
    ].compact.join(" ")
  end

  # `show_at:`/`hide_at:` each name the breakpoint where that state takes
  # effect -- ordered ascending by breakpoint (not by show/hide) so e.g.
  # `hide_at: :xs, show_at: :sm` reads as "d-none d-sm-block" (hidden at
  # xs, then shown from sm up), matching the order the equivalent BS3
  # `.hidden-xs` / `.visible-xs-*` utilities implied.
  def self.visibility_classes(show_at: nil, hide_at: nil)
    entries = []
    entries << [BREAKPOINTS.index(show_at), display_class(show_at, :block)] \
      if show_at
    entries << [BREAKPOINTS.index(hide_at), display_class(hide_at, :none)] \
      if hide_at
    entries.sort_by(&:first).map(&:last)
  end

  # `xs` is Bootstrap 3's mobile-first base -- there's no `d-xs-*` class,
  # just the bare `d-block`/`d-none`.
  def self.display_class(breakpoint, state)
    breakpoint == :xs ? "d-#{state}" : "d-#{breakpoint}-#{state}"
  end

  prop :xs, _Nilable(Integer), default: nil
  prop :sm, _Nilable(Integer), default: nil
  prop :md, _Nilable(Integer), default: nil
  prop :lg, _Nilable(Integer), default: nil
  prop :xl, _Nilable(Integer), default: nil
  prop :offset_xs, _Nilable(Integer), default: nil
  prop :col, _Boolean, default: false
  prop :show_at, _Nilable(Symbol), default: nil
  prop :hide_at, _Nilable(Symbol), default: nil
  prop :element, Symbol, default: :div
  # Catch-all for class:, id:, data:, and any other HTML attrs -- matches
  # Components::Collapsible's / Components::Navbar's pattern. `_Any?`, not
  # bare `_Any` -- Literal's `_Any` excludes `NilClass`.
  prop :attributes, _Hash(Symbol, _Any?), :**

  def view_template(&block)
    send(@element,
         class: class_names(width_classes, @attributes[:class]),
         **@attributes.except(:class),
         &block)
  end

  private

  def width_classes
    self.class.classes_for(xs: @xs, sm: @sm, md: @md, lg: @lg, xl: @xl,
                           offset_xs: @offset_xs, col: @col,
                           show_at: @show_at, hide_at: @hide_at)
  end
end
