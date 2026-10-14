# frozen_string_literal: true

# ==== Request stats
# What every request contributes to `log/ip_stats.txt` and to the TIME
# line in the Rails log. `script/update_ip_stats.rb` reads the former
# once a minute and blocks an address serving more than 20 requests a
# minute with nobody logged in behind it (see `IpStats`).
#
# One kind of request is left out of the count -- see `label_scan?`.
module ApplicationController::RequestStats
  # Catch errors for integration tests, and report stats re completed
  # request.
  def catch_errors_and_log_request_stats
    clear_user_globals
    stats = request_stats
    yield
    IpStats.log_stats(stats, @user&.id) unless label_scan?
    logger.warn(request_stats_log_message(stats))
  rescue StandardError => e
    raise(@error = e)
  end

  private

  # A printed QR code's two requests (lookup, then the `/obs/`
  # redirect) are left out of the count: a group foray puts a
  # roomful of people behind one address, none logged in -- the
  # same shape `update_ip_stats.rb` blocks a scraper for. A blocked
  # address still gets refused these, like any other page.
  #
  # Only the `/obs/` form itself is exempt -- `/observations/:id`
  # and a bare `/:id` still count, since that's where crawlers
  # arrive (96,490 requests in one day, vs. 37 for the busiest human
  # reader of `/obs/`).
  def label_scan?
    return true if params[:controller] == "projects/best_observations" &&
                   params[:action] == "show"
    return false unless params[:controller] == "observations" &&
                        params[:action] == "show"

    request.url.include?(permanent_observation_path(id: params[:id]))
  rescue ActionController::UrlGenerationError
    false
  end

  def request_stats
    {
      time: Time.current,
      controller: params[:controller],
      action: params[:action],
      api_key: params[:api_key],
      robot: browser.bot? ? "robot" : "user",
      ip: request.try(&:remote_ip),
      url: request.try(&:url),
      ua: browser.try(&:ua)
    }
  end

  def request_stats_log_message(stats)
    "TIME: #{Time.current - stats[:time]} #{status} " \
      "#{stats[:controller]} #{stats[:action]} " \
      "#{stats[:robot]} #{stats[:ip]}\t#{stats[:url]}\t#{stats[:ua]}"
  end
end
