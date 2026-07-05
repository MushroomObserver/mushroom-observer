# frozen_string_literal: true

# Bootstrap grid column class constants for responsive layout.
# All values use Bootstrap 3 syntax. When migrating to Bootstrap 4:
#   col-xs-N → col-N, col-xs-offset-N → offset-N
# Update this file and all callers update automatically.
module Grid
  FULL = "col-xs-12"
  # Fixed 50/50 split at every width, including mobile — for small
  # inline pairs that read fine squeezed together (e.g. paired
  # coordinate/link labels). For a column that stacks full-width on
  # mobile and only splits 50/50 from `sm` up, use SM6 instead.
  HALF           = "col-xs-6"
  THIRD          = "col-xs-4"
  QUARTER        = "col-xs-3"
  CENTERED_THIRD = "col-xs-4 col-xs-offset-4"

  SM3 = "col-xs-12 col-sm-3"
  SM4 = "col-xs-12 col-sm-4"
  SM5 = "col-xs-12 col-sm-5"
  SM6 = "col-xs-12 col-sm-6"
  SM7 = "col-xs-12 col-sm-7"
  SM8 = "col-xs-12 col-sm-8"
  SM9 = "col-xs-12 col-sm-9"

  MD6  = "col-xs-12 col-md-6"
  MD10 = "col-xs-12 col-md-10"

  # Full → half → third → quarter across xs/sm/md/lg.
  # Default tile size for Components::Matrix::Box.
  TILE = "col-xs-12 col-sm-6 col-md-4 col-lg-3"

  # Full on xs, half on sm, full on md, half on lg.
  # Used by search/lookup field groups.
  FORM_COLS = "col-xs-12 col-sm-6 col-md-12 col-lg-6"

  # Left/right column-class pairs for the page-level two-column split
  # (`Views::FullPageBase::LayoutClasses#column_classes`). Keyed by
  # the same `columns:` profile names callers pass — `:twelve` is the
  # untouched, no-split default. Unlike the constants above (atomic
  # widths used freely within a page), these pairs are specific to
  # that one page-layout mechanism, so they're not expected to be
  # referenced directly elsewhere.
  LAYOUT_COLUMNS = {
    twelve: [FULL, FULL],
    nine_three: ["col-xs-12 col-md-9 col-lg-8", "col-xs-12 col-md-3 col-lg-4"],
    eight_four: ["col-xs-12 col-md-8 col-lg-7", "col-xs-12 col-md-4 col-lg-5"],
    seven_five: ["col-xs-12 col-md-7", "col-xs-12 col-md-5"],
    six: ["col-xs-12 col-md-6 col-lg-8", "col-xs-12 col-md-6 col-lg-4"],
    six_even: ["col-xs-12 col-lg-6", "col-xs-12 col-lg-6"]
  }.freeze
end
