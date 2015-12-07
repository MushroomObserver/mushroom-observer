require "test_helper"

# Test typical sessions of user who never creates an account or contributes.
class LurkerTest < IntegrationTestCase
  def test_poke_around
    # Start at index.
    # Test page content rather than template because:
    # (1) assert_template unavailable to Capybara
    # (2) assert_template will be deprecated in Rails 5 (but available as a gem)
    #     because (per DHH) testing content is a better practice
    visit(root_path)
    # following gives more informative error message than
    #   assert(page.has_title?("#{:app_title.l }: Activity Log"), "Wrong page")
    assert_equal("#{:app_title.l }: Activity Log", page.title, "Wrong page")

    # Click on first observation in feed results
    results_links = all(".results .rss-what a")
    first_obs_in(results_links).click
    assert_match(%r{#{:app_title.l }: Observation}, page.title, "Wrong page")

    # Click on next (catches a bug seen in the wild).
    # Above comment about "next" does not match "Prev" in code
    # push_page is a stop-gap until a js-enabled driver is installed and working
    push_page
    click_link("« Prev")
    go_back
    assert_match(%r{#{:app_title.l }: Observation}, page.title, "Wrong page")

    # Click on the first image.
    push_page
    first(".show_images a[href^='/image/show_image']").click
    assert_match(%r{#{:app_title.l }: Image}, page.title, "Wrong page")

    # Go back to observation and click on "About...".
    go_back
    assert_match(%r{#{:app_title.l }: Observation}, page.title, "Wrong page")
    click_link("About ")
    assert_match(%r{#{:app_title.l }: Name}, page.title, "Wrong page")

    # Take a look at the occurrence map.
    click_link("Occurrence Map")
    assert_match(%r{#{:app_title.l }: Occurrence Map}, page.title, "Wrong page")

    # Check out a few links from left-hand panel.
    click_on("How To Use")
    assert_match(%r{#{:app_title.l }: How to Use}, page.title, "Wrong page")

    click_on("Français")
    assert_match(%r{#{:app_title.l }: How to Use}, page.title, "Wrong page")

    click_on("Contributeurs")
    assert_equal("#{:app_title.l }: List of Contributors",
                 page.title, "Wrong page")

    click_on("English")
    assert_equal("#{:app_title.l }: List of Contributors",
                 page.title, "Wrong page")

    click_on("List Projects")
    assert_equal("#{:app_title.l }: Project Index", page.title, "Wrong page")

    click_on("Comments")
    assert_equal("#{:app_title.l }: Comment Index", page.title, "Wrong page")

    click_on("Site Stats")
    assert_equal("#{:app_title.l }: Site Statistics", page.title, "Wrong page")
  end

  # css selectors cannot match a regex, so must use Ruby to match
  def first_obs_in(capybara_result)
    capybara_result.select{ |r| r[:href] =~ %r{^/\d+} }.first
  end

  # Save current page on the page stack
  # Stop-gap until webkit or selenium is installed and working with Capybara
  #   Then this method and calls to it should be removed.
  def push_page
    @page_stack ? @page_stack.push(current_path) : @page_stack = [current_path]
  end

  # Fakes clicking browser "Back" link
  # Stop-gap until webkit or selenium is installed and working with Capybara
  #   Then this method should be removed, and calls to it should instead use
  #   appropriate Capybara method like Capybara::Webkit::Driver#go_back
  #   which will better simulate clicking that link
  def go_back
    visit(@page_stack.pop)
  end

end
