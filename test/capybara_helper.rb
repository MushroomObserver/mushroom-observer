# frozen_string_literal: true

module CapybaraHelper
  ### locators ###
  # Xpath for 1st link in each feed item,
  #   which items display "Observation Created"
  def rss_observation_created_xpath
    "(//div[contains(@class, 'rss-box-details')]"\
      "[descendant::div[contains(@class, 'rss-detail') and"\
                        "normalize-space(text()) = 'Observation Created']]"\
      "//a[1])"
  end

  # XPath for Images in an Observation
  def observation_image_xpath
    "//div[@id='content']/descendant::div[contains(@class, 'show_images')]/
                          descendant::a[child::img]"
  end

  ### driver simulators ###
  # temporary methods for Capybara tests until webdriver is installed
  ###
  # Fake clicking browser "Back" link. Example:
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
