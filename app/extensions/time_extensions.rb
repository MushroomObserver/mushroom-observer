#
#  = Extensions to TimeWithZone
#
#  TimeWithZone is a Rails class that supercedes Time and DateTime.  We've
#  added these simple wrappers to standardize the formatting of dates and times
#  throughout the site.  They are also made available to the three core classes
#  (Date, Time, DateTime), just in case. 
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
################################################################################

class ActiveSupport::TimeWithZone
  Date::DATE_FORMATS[:web]   = WEB_DATE_FORMAT
  Time::DATE_FORMATS[:web]   = WEB_TIME_FORMAT
  Date::DATE_FORMATS[:api]   = API_DATE_FORMAT
  Time::DATE_FORMATS[:api]   = API_TIME_FORMAT
  Date::DATE_FORMATS[:email] = EMAIL_DATE_FORMAT
  Time::DATE_FORMATS[:email] = EMAIL_TIME_FORMAT

  # Format as date for API XML responses.
  def web_date; strftime(WEB_DATE_FORMAT); end

  # Format as date-time for API XML responses.
  def web_time; strftime(WEB_TIME_FORMAT); end

  # Format as date for API XML responses.
  def api_date; utc.strftime(API_TIME_FORMAT); end

  # Format as date-time for API XML responses.
  def api_time; utc.strftime(API_TIME_FORMAT); end

  # Format as date for emails.
  def email_date; strftime(EMAIL_TIME_FORMAT); end

  # Format as date-time for emails.
  def email_time; strftime(EMAIL_TIME_FORMAT); end
end

class Time
  def web_date;   in_time_zone.web_date;   end
  def web_time;   in_time_zone.web_time;   end
  def api_date;   in_time_zone.api_date;   end
  def api_time;   in_time_zone.api_time;   end
  def email_date; in_time_zone.email_date; end
  def email_time; in_time_zone.email_time; end
end

class DateTime
  def web_date;   in_time_zone.web_date;   end
  def web_time;   in_time_zone.web_time;   end
  def api_date;   in_time_zone.api_date;   end
  def api_time;   in_time_zone.api_time;   end
  def email_date; in_time_zone.email_date; end
  def email_time; in_time_zone.email_time; end
end

class Date
  def web_date;   strftime(WEB_DATE_FORMAT); end
  def api_date;   strftime(API_DATE_FORMAT); end
  def email_date; strftime(EMAIL_DATE_FORMAT); end
end
