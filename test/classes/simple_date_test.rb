# frozen_string_literal: true

require("test_helper")

class SimpleDateTest < UnitTestCase
  def test_from_date
    simple_date = SimpleDate.from_date(Date.new(2024, 1, 15))

    assert_equal(15, simple_date.day)
    assert_equal(1, simple_date.month)
    assert_equal(2024, simple_date.year)
  end

  def test_from_date_nil
    assert_nil(SimpleDate.from_date(nil))
  end

  def test_to_json
    simple_date = SimpleDate.new(day: 15, month: 1, year: 2024)

    assert_equal('{"day":15,"month":1,"year":2024}', simple_date.to_json)
  end

  def test_to_display
    simple_date = SimpleDate.new(day: 15, month: 1, year: 2024)

    assert_equal("15-January-2024", simple_date.to_display)
  end
end
