# encoding: utf-8
# temporary methods for Capybara tests until webdriver is installed
module WebDriverExtensions
  # Fake clicking browser "Back" link. xample:
  #   go_back_after do
  #     click_link("« Prev")
  #     ...
  #   end
  #
  # Capybara has built-in go_back and go_forward methods.  They require
  # installation of a js-enabled driver like webkit or selenium.
  # Once such a driver is installed, this method should be removed,
  # we should instead use appropriate Capybara method like
  # Capybara::Webkit::Driver#go_back
  def go_back_after(&block)
    @page_stack ? @page_stack.push(current_path) : @page_stack = [current_path]
    yield(block)
    visit(@page_stack.pop)
  end
end
