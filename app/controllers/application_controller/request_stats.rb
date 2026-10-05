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

  # A printed QR code's two requests: the lookup, and the `/obs/` page
  # it redirects to. A fair puts a roomful of people behind one
  # address, none of them logged in, which is the shape
  # update_ip_stats.rb blocks a scraper for -- so the scans are left
  # out of the count. Only out of the count: a blocked address is
  # still refused these, like any other page.
  #
  # The `/obs/` form alone, tested the way check_for_spider_block tests
  # it, so the pages MO lets a logged-out visitor read and the pages it
  # declines to meter stay the same set. `/observations/:id` and a bare
  # `/:id` are where the crawlers arrive, and they still count: 96,490
  # requests in one day, against 37 for the busiest reader of `/obs/`.
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
