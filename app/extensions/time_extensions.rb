# frozen_string_literal: true

#
#  = Extensions to TimeWithZone
#
#  TimeWithZone is a Rails class that supercedes Time and DateTime.  We've
#  added these simple wrappers to standardize the formatting of dates and times
#  throughout the site.
#
#  == Instance Methods
#
#  web_date::       Format as date for website UI.
#  web_time::       Format as date-time for website UI.
#  api_date::       Format as date for API XML responses.
#  api_time::       Format as date-time for API XML responses.
#  email_date::     Format as date for emails.
#  email_time::     Format as date-time for emails.
#
class ActiveSupport::TimeWithZone
  Date::DATE_FORMATS[:web]   = MO.web_date_format
  Time::DATE_FORMATS[:web]   = MO.web_time_format
  Date::DATE_FORMATS[:api]   = MO.api_date_format
  Time::DATE_FORMATS[:api]   = MO.api_time_format
  Date::DATE_FORMATS[:email] = MO.email_date_format
  Time::DATE_FORMATS[:email] = MO.email_time_format

  # Format as date for API XML responses.
  def web_date
    strftime(MO.web_date_format)
  end

  # Format as date-time for API XML responses.
  def web_time
    strftime(MO.web_time_format)
  end

  # Format as date for API XML responses.
  def api_date
    utc.strftime(MO.api_time_format)
  end

  # Format as date-time for API XML responses.
  def api_time
    utc.strftime(MO.api_time_format)
  end

  # Format as date for emails.
  def email_date
    strftime(MO.email_time_format)
  end

  # Format as date-time for emails.
  def email_time
    strftime(MO.email_time_format)
  end
end

# Make MO date and time formats available to Time, just in case.
class Time
  delegate :web_date, to: :in_time_zone

  delegate :web_time, to: :in_time_zone

  delegate :api_date, to: :in_time_zone

  delegate :api_time, to: :in_time_zone

  delegate :email_date, to: :in_time_zone

  delegate :email_time, to: :in_time_zone

  # dd Mon yyyy hh:mm:ss
  def display_time
    strftime("%F %T")
  end
end

# Make MO date formats available to Date, just in case.
class Date
  def web_date
    strftime(MO.web_date_format)
  end

  def api_date
    strftime(MO.api_date_format)
  end

  def email_date
    strftime(MO.email_date_format)
  end
end

# Make MO Time formats available to DateTime, just in case.
# DateTime inherits MO Date formats from Date, its superclass.
class DateTime
  delegate :web_time, to: :in_time_zone

  delegate :api_time, to: :in_time_zone

  delegate :email_time, to: :in_time_zone
end
