# frozen_string_literal: true

require("application_system_test_case")

# End-to-end coverage of `Components::Description::NewDraftForm`'s
# JS-driven interaction -- picking a project via the autocompleter
# and confirming the main form locks to it. The equivalent in
# `test/integration/capybara/name_descriptions_integration_test.rb`
# can't drive this (it runs on the JS-less `rack_test` driver), so
# it visits the resulting URL directly instead.
class DescriptionNewDraftSystemTest < ApplicationSystemTestCase
  def setup
    super
    @browser = page.driver.browser
  end

  def test_pick_project_draft_via_autocompleter
    name = names(:coprinus_comatus)
    project = projects(:eol_project)
    login!(users(:rolf)) # member and admin of eol_project

    visit(new_name_description_path(name_id: name.id))
    assert_selector("body.descriptions__new")

    # Before picking: the picker is present, and the main form is
    # still in its default (unlocked) state -- a source-type
    # dropdown, not yet committed to a project.
    assert_field("project")
    within("#name_description_form") do
      assert_selector("select[name='description[source_type]']")
    end

    # Pick the project via the autocompleter.
    find_field("project").click
    @browser.keyboard.type("EOL")
    assert_selector(".auto_complete") # wait for the dropdown
    assert_selector(".auto_complete ul li a", text: project.title)
    @browser.keyboard.type(:down, :tab)
    assert_field("project", with: project.title)

    # Scoped: the main form below also has a "Create" submit button.
    within("#new_draft_form") { click_button("Create") }

    # After picking: the main form is locked to the chosen project
    # (no more dropdown, the project name shown as plain text), and
    # the picker itself is gone -- nothing left to pick.
    assert_selector("body.descriptions__new")
    assert_no_field("project")
    within("#name_description_form") do
      assert_no_selector("select[name='description[source_type]']")
      assert_text(project.title)
    end
  end
end
