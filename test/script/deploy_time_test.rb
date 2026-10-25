# frozen_string_literal: true

require("test_helper")
require(Rails.root.join("script/deploy_time").to_s)

# How script/deploy_time.rb reads a typed deploy time. Local is London,
# whose clocks go back at 01:00 UTC on 2026-10-25 and forward at 01:00
# UTC on 2026-03-29; New York's go back on 2026-11-01.
class DeployTimeTest < UnitTestCase
  MORNING = Time.utc(2026, 10, 25, 6, 30) # a Sunday
  EVENING = Time.utc(2026, 10, 25, 21, 0)

  def test_times_of_day_take_the_next_occurrence
    {
      "8" => [Time.utc(2026, 10, 25, 8), Time.utc(2026, 10, 26, 8)],
      "8:00" => [Time.utc(2026, 10, 25, 8), Time.utc(2026, 10, 26, 8)],
      "8:30" => [Time.utc(2026, 10, 25, 8, 30), Time.utc(2026, 10, 26, 8, 30)],
      "08:00" => [Time.utc(2026, 10, 25, 8), Time.utc(2026, 10, 26, 8)],
      "20:00" => [Time.utc(2026, 10, 25, 20), Time.utc(2026, 10, 26, 20)],
      "8pm" => [Time.utc(2026, 10, 25, 20), Time.utc(2026, 10, 26, 20)],
      "8 PM" => [Time.utc(2026, 10, 25, 20), Time.utc(2026, 10, 26, 20)],
      "8am" => [Time.utc(2026, 10, 25, 8), Time.utc(2026, 10, 26, 8)],
      "12am" => [Time.utc(2026, 10, 26), Time.utc(2026, 10, 26)],
      "12pm" => [Time.utc(2026, 10, 25, 12), Time.utc(2026, 10, 26, 12)],
      "12" => [Time.utc(2026, 10, 25, 12), Time.utc(2026, 10, 26)],
      "0:30" => [Time.utc(2026, 10, 26, 0, 30), Time.utc(2026, 10, 26, 0, 30)],
      "noon" => [Time.utc(2026, 10, 25, 12), Time.utc(2026, 10, 26, 12)],
      "midnight" => [Time.utc(2026, 10, 26), Time.utc(2026, 10, 26)]
    }.each do |text, (morning, evening)|
      assert_equal(morning, parse(text, now: MORNING), "#{text} at 06:30")
      assert_equal(evening, parse(text, now: EVENING), "#{text} at 21:00")
    end
  end

  # An ambiguous time on a given day is the first one that day.
  def test_days
    {
      "08:00 tomorrow" => Time.utc(2026, 10, 26, 8),
      "tomorrow 8pm" => Time.utc(2026, 10, 26, 20),
      "8 tomorrow" => Time.utc(2026, 10, 26, 8),
      "tomorrow at 8" => Time.utc(2026, 10, 26, 8),
      "today 8pm" => Time.utc(2026, 10, 25, 20),
      "day after tomorrow 8" => Time.utc(2026, 10, 27, 8),
      "monday 8am" => Time.utc(2026, 10, 26, 8),
      "8am mon" => Time.utc(2026, 10, 26, 8),
      "sunday 8" => Time.utc(2026, 10, 25, 8),
      "sunday 6am" => Time.utc(2026, 11, 1, 6),
      "2026-10-28 08:00" => Time.utc(2026, 10, 28, 8),
      "2026-10-28T08:00Z" => Time.utc(2026, 10, 28, 8),
      "2026-10-28T08:00+02:00" => Time.utc(2026, 10, 28, 6)
    }.each do |text, expected|
      assert_equal(expected, parse(text), text)
    end
  end

  def test_a_bst_date_converts_with_bst
    assert_equal(Time.utc(2026, 7, 1, 7), parse("2026-07-01 08:00"))
  end

  def test_the_repeated_fall_back_hour_takes_its_first_occurrence
    assert_equal(Time.utc(2026, 10, 25, 0, 30), parse("2026-10-25 01:30"))
  end

  def test_a_skipped_spring_forward_time_is_an_error
    assert_parse_error(%r{doesn't exist in Europe/London}, "2026-03-29 01:30")
  end

  def test_zones
    {
      "8pm UTC" => [Time.utc(2026, 10, 25, 20), "UTC"],
      "8pm gmt" => [Time.utc(2026, 10, 25, 20), "UTC"],
      "8pm eastern" => [Time.utc(2026, 10, 26), "eastern (America/New_York)"],
      "8pm ET" => [Time.utc(2026, 10, 26), "et (America/New_York)"],
      "8 pacific" => [Time.utc(2026, 10, 25, 15), "pacific " \
                                                  "(America/Los_Angeles)"],
      "8pm EDT" => [Time.utc(2026, 10, 26), "EDT"],
      "2026-11-02 8am EST" => [Time.utc(2026, 11, 2, 13), "EST"],
      "2026-07-01 8pm mst" => [Time.utc(2026, 7, 2, 3), "MST"],
      "2026-07-01 8pm bst" => [Time.utc(2026, 7, 1, 19), "BST"],
      "8pm America/New_York" => [Time.utc(2026, 10, 26), "America/New_York"],
      "8pm america/new_york" => [Time.utc(2026, 10, 26), "America/New_York"],
      "8pm +02:00" => [Time.utc(2026, 10, 25, 18), "+02:00"],
      "8pm -0530" => [Time.utc(2026, 10, 26, 1, 30), "-0530"]
    }.each do |text, (time, zone)|
      result = DeployTime.parse(text, now: MORNING, local_zone: "Europe/London")
      assert_equal([time, zone], [result.time, result.zone], text)
    end
  end

  def test_an_abbreviation_out_of_season_is_rejected
    assert_parse_error(
      %r{EST isn't in use on 2026-07-01; America/New_York is on EDT},
      "2026-07-01 8pm EST"
    )
    assert_parse_error(
      %r{BST isn't in use on 2026-10-25; Europe/London is on GMT}, "8pm BST"
    )
  end

  def test_the_local_zone_is_labeled
    result = DeployTime.parse("8pm", now: MORNING, local_zone: "Europe/London")

    assert_equal("Europe/London (local)", result.zone)
  end

  def test_bad_input
    {
      "" => /no time of day/,
      "tomorrow" => /no time of day/,
      "2026-10-28" => /no time of day/,
      "banana" => /didn't understand "banana"/,
      "8pm banana" => /didn't understand "banana"/,
      "13pm" => /13pm is not a time/,
      "25:00" => /25:00 is not a time/,
      "8:75" => /8:75 is not a time/,
      "2026-02-30 8am" => /2026-02-30 is not a date/,
      "8pm EST UTC" => /more than one time zone/,
      "tomorrow monday 8" => /more than one day/
    }.each do |text, message|
      assert_parse_error(message, text)
    end
  end

  def test_errors_quote_the_input_and_give_examples
    error = assert_raises(DeployTime::Error) { parse("banana") }

    assert_equal("Bad deploy time \"banana\": didn't understand " \
                 "\"banana\" (#{DeployTime::EXAMPLES}).", error.message)
  end

  def test_an_unknown_local_zone_is_an_error
    error = assert_raises(DeployTime::Error) do
      DeployTime.parse("8pm", now: MORNING, local_zone: "Nowhere/Land")
    end

    assert_match(%r{unknown time zone Nowhere/Land}, error.message)
  end

  def test_no_local_zone_asks_for_one
    DeployTime.stub(:local_zone_name, nil) do
      error = assert_raises(DeployTime::Error) do
        DeployTime.parse("8pm", now: MORNING)
      end

      assert_match(/can't tell this machine's time zone; add one/,
                   error.message)
    end
  end

  def test_local_zone_name_from_tz_then_localtime
    with_tz(":America/Chicago") do
      assert_equal("America/Chicago", DeployTime.local_zone_name)
    end
    with_tz(nil) do
      File.stub(:readlink, "/var/db/timezone/zoneinfo/Europe/London") do
        assert_equal("Europe/London", DeployTime.local_zone_name)
      end
      File.stub(:readlink, ->(_) { raise(Errno::ENOENT) }) do
        assert_nil(DeployTime.local_zone_name)
      end
    end
  end

  def test_every_abbreviation_is_used_by_one_of_its_zones
    seasons = [Time.utc(2026, 1, 15), Time.utc(2026, 7, 15)]
    DeployTime::ABBREVIATIONS.each do |abbreviation, zones|
      used = zones.product(seasons).map do |zone, time|
        TZInfo::Timezone.get(zone).period_for_utc(time).abbreviation
      end
      assert_includes(used.map(&:downcase), abbreviation)
    end
  end

  private

  def parse(text, now: MORNING)
    DeployTime.parse(text, now: now, local_zone: "Europe/London").time
  end

  def assert_parse_error(message, text)
    error = assert_raises(DeployTime::Error, text) { parse(text) }
    assert_match(message, error.message, text)
  end

  def with_tz(value)
    old = ENV.fetch("TZ", nil)
    value ? ENV["TZ"] = value : ENV.delete("TZ")
    yield
  ensure
    old ? ENV["TZ"] = old : ENV.delete("TZ")
  end
end
