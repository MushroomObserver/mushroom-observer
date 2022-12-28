# frozen_string_literal: true

# https://www.railsagency.com/blog/2020/03/11/how-to-configure-full-stack-integration-testing-with-selenium-and-ruby-on-rails/
module CapybaraMacros
  def scroll_to_bottom
    page.execute_script("window.scrollBy(0,10000)")
  end

  def wait_for_ajax
    Timeout.timeout(Capybara.default_max_wait_time) do
      loop until finished_all_ajax_requests?
    end
  end

  def finished_all_ajax_requests?
    page.evaluate_script("jQuery.active").zero?
  end

  # Do not commit this - it will freeze your CI server as it requires
  # keyboard input to exit from.
  # https://ricostacruz.com/til/pausing-capybara-selenium
  # Also, not to be confused with Kernel#pause
  def pause_selenium
    $stderr.write("Press enter to continue")
    $stdin.gets
  end

  # NOTE: sort of a hack to make element visible on page
  def maximize_browser_window
    Capybara.current_session.current_window.resize_to(1000, 1000)
  end
end
