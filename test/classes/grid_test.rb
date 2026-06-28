# frozen_string_literal: true

require("test_helper")

# Pins the Bootstrap 3 column class strings in Grid so that a future
# Bootstrap 4 migration (col-xs-N → col-N, col-xs-offset-N → offset-N)
# shows up as deliberate test failures rather than silent drift.
class GridTest < UnitTestCase
  def test_simple_widths
    assert_equal("col-xs-12", Grid::FULL)
    assert_equal("col-xs-6",  Grid::HALF)
    assert_equal("col-xs-4",  Grid::THIRD)
    assert_equal("col-xs-3",  Grid::QUARTER)
    assert_equal("col-xs-4 col-xs-offset-4", Grid::CENTERED_THIRD)
  end

  def test_sm_responsive
    assert_equal("col-xs-12 col-sm-3", Grid::SM3)
    assert_equal("col-xs-12 col-sm-4", Grid::SM4)
    assert_equal("col-xs-12 col-sm-5", Grid::SM5)
    assert_equal("col-xs-12 col-sm-7", Grid::SM7)
    assert_equal("col-xs-12 col-sm-8", Grid::SM8)
    assert_equal("col-xs-12 col-sm-9", Grid::SM9)
  end

  def test_md_responsive
    assert_equal("col-xs-12 col-md-6",  Grid::MD6)
    assert_equal("col-xs-12 col-md-10", Grid::MD10)
  end

  def test_complex_responsive
    assert_equal("col-xs-12 col-sm-6 col-md-4 col-lg-3", Grid::TILE)
    assert_equal("col-xs-12 col-sm-6 col-md-12 col-lg-6", Grid::FORM_COLS)
  end
end
