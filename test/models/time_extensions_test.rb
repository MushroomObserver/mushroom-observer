# frozen_string_literal: true

require("test_helper")
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
    @object = Time.zone.today
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
