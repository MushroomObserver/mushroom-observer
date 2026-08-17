# frozen_string_literal: true

require("test_helper")

class DateRangeParserTest < UnitTestCase
  def parse(string)
    DateRangeParser.new(string).range
  end

  def test_single_values
    assert_equal(%w[2026-08-12 2026-08-12], parse("2026-08-12"))
    assert_equal(%w[2026-01-01 2026-12-31], parse("2026"))
    assert_equal(%w[08-01 08-31], parse("8"))
  end

  def test_dash_ranges
    assert_equal(%w[2026-08-12 2026-08-16], parse("2026-08-12-2026-08-16"))
    assert_equal(%w[2026-01-01 2027-12-31], parse("2026-2027"))
    assert_equal(%w[02-01 08-31], parse("02-08"))
  end

  # Two full dates separated by a comma is the natural way to write a
  # range; the dash-only grammar used to return nil for it, and the
  # search silently dropped the filter (reported: a locality + date
  # search returning observations from every year).
  def test_comma_ranges
    assert_equal(%w[2026-08-12 2026-08-16], parse("2026-08-12,2026-08-16"))
    assert_equal(%w[2026-08-12 2026-08-16], parse("2026-08-12, 2026-08-16"))
    assert_equal(%w[2026-01-01 2027-12-31], parse("2026,2027"))
    assert_equal(%w[2026-08-01 2026-09-30], parse("2026-08,2026-09"))
  end

  def test_comma_range_with_date_words
    today = Time.zone.today.strftime("%Y-%m-%d")
    first = Time.zone.today.beginning_of_month.strftime("%Y-%m-%d")

    assert_equal([first, today], parse("this_month,today"))
  end

  # A space works as the separator too -- but only after the whole
  # string fails to parse, so spaced date words ("2 days ago") stay
  # one date, not a range.
  def test_space_ranges
    assert_equal(%w[2026-08-12 2026-08-16], parse("2026-08-12 2026-08-16"))
    assert_equal(%w[2026-01-01 2027-12-31], parse("2026 2027"))
    assert_equal(%w[2026-08-01 2026-09-30], parse("2026-08 2026-09"))

    two_days_ago = 2.days.ago.strftime("%Y-%m-%d")

    assert_equal([two_days_ago, two_days_ago], parse("2 days ago"))
  end

  def test_unparseable_values_are_nil
    assert_nil(parse("garbage"))
    assert_nil(parse("nonsense,2026"))
    assert_nil(parse("2026-08-12,"))
    assert_nil(parse(""))
    assert_nil(parse(nil))
  end

  # Exactly two endpoints: a list of three dates is rejected, not
  # silently spanned first-to-last.
  def test_separators_do_not_nest
    assert_nil(parse("2026-08-12,2026-08-16,2026-08-17"))
    assert_nil(parse("2026-08-12 2026-08-16 2026-08-17"))
    assert_nil(parse("2026-08-12,2026-08-16 2026-08-17"))
  end
end
