# encoding: utf-8
# temporary methods for Capybara tests until webdriver is installed
module WebDriverExtensions
  # Fake clicking browser "Back" link. xample:
  #   push_page
  #   click_link("« Prev")
  #   go_back
  #
  # Stop-gap until webkit or selenium is installed and working with Capybara
  #   Then this method should be removed, and calls to it should instead use
  #   appropriate Capybara method like Capybara::Webkit::Driver#go_back
  #   which will better simulate clicking that link
  def go_back
    visit(@page_stack.pop)
  end

  # Save current page on page stack. Use whenever using go_back. Example:
  #   push_page
  #   click_link("« Prev")
  #   go_back
  #
  # Stop-gap until webkit or selenium is installed and working with Capybara
  #   Then this method and calls to it should be removed.
  def push_page
    @page_stack ? @page_stack.push(current_path) : @page_stack = [current_path]
  end
end
