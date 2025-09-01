# frozen_string_literal: true

class UnitTestCase < ActiveSupport::TestCase
  include GeneralExtensions

  def setup
    Location.update_box_area_and_center_columns
  end
end
