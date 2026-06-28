# frozen_string_literal: true

# Bootstrap grid column class constants for responsive layout.
# All values use Bootstrap 3 syntax. When migrating to Bootstrap 4:
#   col-xs-N → col-N, col-xs-offset-N → offset-N
# Update this file and all callers update automatically.
module Grid
  FULL           = "col-xs-12"
  HALF           = "col-xs-6"
  THIRD          = "col-xs-4"
  QUARTER        = "col-xs-3"
  CENTERED_THIRD = "col-xs-4 col-xs-offset-4"

  SM3 = "col-xs-12 col-sm-3"
  SM4 = "col-xs-12 col-sm-4"
  SM5 = "col-xs-12 col-sm-5"
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
end
