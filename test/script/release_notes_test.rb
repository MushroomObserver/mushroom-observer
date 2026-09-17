# frozen_string_literal: true

require("test_helper")
require(Rails.root.join("script/release_notes").to_s)

# Deploy schedule and banner text for the release scripts.
class ReleaseNotesTest < UnitTestCase
  # 8am Eastern: 12:00 UTC in daylight time, 13:00 UTC in standard time.
  # 2026 falls back on Nov 1 and springs forward on Mar 8.
  def test_next_deploy_time_stays_at_8am_eastern
    {
      Time.utc(2026, 9, 17, 11) => Time.utc(2026, 9, 17, 12),
      Time.utc(2026, 9, 17, 12) => Time.utc(2026, 9, 17, 12),
      Time.utc(2026, 9, 17, 12, 1) => Time.utc(2026, 9, 18, 12),
      Time.utc(2026, 11, 1, 12, 30) => Time.utc(2026, 11, 1, 13),
      Time.utc(2026, 11, 1, 13, 30) => Time.utc(2026, 11, 2, 13),
      Time.utc(2026, 3, 7, 14) => Time.utc(2026, 3, 8, 12)
    }.each do |now, expected|
      assert_equal(expected, ReleaseNotes.next_deploy_time(now), "from #{now}")
    end
  end

  def test_deploy_time_on_a_date
    assert_equal(Time.utc(2026, 12, 1, 13),
                 ReleaseNotes.deploy_time_on(Date.new(2026, 12, 1)))
  end

  def test_pending_banner_line_at_the_usual_noon_deploy
    assert_equal(
      "Next release Sep 15 noon UTC (8am eastern, 5am pacific). " \
      "See \"pre-release change log\":https://github.com/MushroomObserver/" \
      "mushroom-observer/blob/changelog-pending/CHANGELOG.md for details",
      ReleaseNotes.pending_banner_line(Time.utc(2026, 9, 15, 12))
    )
  end

  def test_pending_banner_line_off_noon_in_standard_time
    line = ReleaseNotes.pending_banner_line(Time.utc(2026, 12, 1, 14, 30))

    assert_equal("Next release Dec 1 14:30 UTC " \
                 "(9:30am eastern, 6:30am pacific).",
                 line[/\A[^.]*\./])
  end

  def test_released_banner_line_links_the_article_or_the_changelog
    time = Time.utc(2026, 9, 15, 12, 20)

    assert_equal(
      "Sep 15 release complete. See \"MO Improvements\":" \
      "https://mushroomobserver.org/articles/#{ReleaseNotes::ARTICLE_ID} " \
      "for details",
      ReleaseNotes.released_banner_line(time, user_facing: true)
    )
    assert_equal(
      "Sep 15 release complete. No user-facing changes - \"details here\":" \
      "https://github.com/MushroomObserver/mushroom-observer/blob/main/" \
      "CHANGELOG.md",
      ReleaseNotes.released_banner_line(time, user_facing: false)
    )
  end

  def test_forced_banner_line_gives_the_time
    assert_equal("Undocumented forced deploy occurred Dec 1 14:32 UTC " \
                 "(9:32am eastern, 6:32am pacific)",
                 ReleaseNotes.forced_banner_line(Time.utc(2026, 12, 1, 14, 32)))
  end

  def test_with_first_line_keeps_the_break_and_later_lines
    message = "Next release soon<br/>\r\nSupport the collection.<br/>\n" \
              "Email the webmaster."

    assert_equal("Released<br/>\r\nSupport the collection.<br/>\n" \
                 "Email the webmaster.",
                 ReleaseNotes.with_first_line(message, "Released"))
    assert_equal("Released", ReleaseNotes.with_first_line("Old", "Released"),
                 "a one-line banner has no break to keep")
  end
end
