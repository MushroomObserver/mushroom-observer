# frozen_string_literal: true

require("test_helper")

class UserStatsHelperTest < ActionView::TestCase
  # Lines 24-25: languages hash triggers the span-building block
  def test_user_stats_rows_includes_language_summary_span
    stats = UserStats.new(
      user: users(:rolf),
      languages: { "en" => 5 }
    )

    rows = user_stats_rows(stats)
    lang_row = rows.last

    assert(lang_row[:label].to_s.include?("English"),
           "Expected language label to include the locale name")
  end

  # Line 35: bonuses array triggers the bonus row block
  def test_user_stats_rows_includes_bonus_rows
    stats = UserStats.new(
      user: users(:rolf),
      bonuses: [[100, "helped curate"]]
    )

    rows = user_stats_rows(stats)
    bonus_row = rows.last

    assert_equal(100, bonus_row[:points],
                 "Expected bonus points in the last row")
  end
end
