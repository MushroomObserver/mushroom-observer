require "test_helper"
# MO time extensions wrap Date, DateTime, and Time
# So test need to use those Classes in ways which offend RuboCop

# test public interface of a class which includes date
module DateExtensionsInterfaceTest
  def test_responds_to_api_date
    assert_respond_to(@object, :api_date)
  end

  def test_responds_to_email_date
    assert_respond_to(@object, :email_date)
  end

  def test_responds_to_web_date
    assert_respond_to(@object, :web_date)
  end
end

# test public interface of class which includes time
module TimeExtensionsInterfaceTest
  def test_responds_to_api_time
    assert_respond_to(@object, :api_time)
  end

  def test_responds_to_email_time
    assert_respond_to(@object, :email_time)
  end

  def test_responds_to_web_time
    assert_respond_to(@object, :web_time)
  end
end

# test MO extensions to Rails' TimeWithZone class
class TimeWithZoneExtensionsTest < ActiveSupport::TestCase
  include DateExtensionsInterfaceTest
  include TimeExtensionsInterfaceTest

  def setup
    @object = Time.zone.now
  end
end

# test MO extensions to Ruby's Date class
class DateExtensionsTest < ActiveSupport::TestCase
  include DateExtensionsInterfaceTest

  def setup
    @object = Date.today
  end
end

# test MO extensions to Ruby's DateTime class
class DateTimeExtensionsTest < ActiveSupport::TestCase
  include DateExtensionsInterfaceTest
  include TimeExtensionsInterfaceTest

  def setup
    @object = DateTime.now
  end
end

# test MO extensions to Ruby's Time class
class TimeExtensionsTest < ActiveSupport::TestCase
  include DateExtensionsInterfaceTest
  include TimeExtensionsInterfaceTest

  def setup
    @object = Time.zone.now
  end

  def test_fancy_time
    assert_fancy_time(0.seconds, :time_just_seconds_ago)
    assert_fancy_time(59.seconds, :time_just_seconds_ago)
    assert_fancy_time(60.seconds, :time_one_minute_ago)
    assert_fancy_time(119.seconds, :time_one_minute_ago)
    assert_fancy_time(120.seconds, :time_minutes_ago, n: 2)
    assert_fancy_time(59.minutes, :time_minutes_ago, n: 59)
    assert_fancy_time(60.minutes, :time_one_hour_ago)
    assert_fancy_time(119.minutes, :time_one_hour_ago)
    assert_fancy_time(120.minutes, :time_hours_ago, n: 2)
    assert_fancy_time(23.hours, :time_hours_ago, n: 23)
    assert_fancy_time(24.hours, :time_one_day_ago)
    assert_fancy_time(7.days, :time_one_week_ago)
    assert_fancy_time(15.days, :time_weeks_ago, n: 2)
    assert_fancy_time(6.weeks, :time_one_month_ago)
    assert_fancy_time(9.weeks, :time_months_ago, n: 2)
  end

  def assert_fancy_time(diff, tag, args = {})
    ref = Time.zone.now
    time = ref - diff
    expect = tag.l(args.merge(date: time.web_date))
    actual = time.fancy_time(ref)
    assert_equal(expect, actual)
  end

  def test_future_fancy_time
    ref = Time.zone.now
    ten_minutes_away = ref + 10.minutes
    fancy_future_time = ten_minutes_away.fancy_time(ref)
    expect = ten_minutes_away.in_time_zone.strftime(MO.web_time_format)

    assert_equal(expect, fancy_future_time)
  end
end
