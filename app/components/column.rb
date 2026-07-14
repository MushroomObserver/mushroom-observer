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
class Components::Column < Components::Base
  BREAKPOINTS = [:xs, :sm, :md, :lg, :xl].freeze

  # Callable without instantiating -- for call sites that need a raw class
  # string merged into an existing element's `class:` rather than a full
  # Column-wrapped element (Components::Matrix::Box's `columns:` prop
  # default, Views::Layouts::Header#title_cols).
  def self.classes_for(col: false, offset_xs: nil, **widths)
    [
      ("col" if col),
      *BREAKPOINTS.filter_map { |bp| "col-#{bp}-#{widths[bp]}" if widths[bp] },
      ("col-xs-offset-#{offset_xs}" if offset_xs)
    ].compact.join(" ")
  end

  prop :xs, _Nilable(Integer), default: nil
  prop :sm, _Nilable(Integer), default: nil
  prop :md, _Nilable(Integer), default: nil
  prop :lg, _Nilable(Integer), default: nil
  prop :xl, _Nilable(Integer), default: nil
  prop :offset_xs, _Nilable(Integer), default: nil
  prop :col, _Boolean, default: false
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
                           offset_xs: @offset_xs, col: @col)
  end
end
