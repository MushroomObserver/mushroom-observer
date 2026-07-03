# frozen_string_literal: true

require("application_system_test_case")

# System tests for Components::Accordion — the Bootstrap 3 multi-pane
# collapse component. Uses the account API keys page as the fixture,
# which renders an Accordion for each key's inline notes editor.
class AccordionSystemTest < ApplicationSystemTestCase
  def setup
    super
    @mary = users("mary")
    @key = api_keys("marys_api_key")
    login!(@mary)
    visit(account_api_keys_path)
  end

  # 1. Edit opens the form pane, hiding the view pane.
  # 2. Cancel reverts to the view pane.
  # 3. Edit opens the form pane again.
  # 4. Submitting the form changes the notes.
  # 5. After submit the view pane is visible with the new notes.
  def test_accordion_open_cancel_reopen_edit_and_submit
    key_id = @key.id
    view_pane_id = "view_notes_#{key_id}_container"
    edit_pane_id = "edit_notes_#{key_id}_container"

    # Initial state: view pane open, edit pane collapsed (hidden).
    assert_selector("##{view_pane_id}.collapse.in")
    assert_selector("##{edit_pane_id}.collapse", visible: :hidden)
    assert_no_selector("##{edit_pane_id}.in")

    # 1. Click "Edit" — edit pane opens, view pane collapses.
    within("#notes_#{key_id}") { click_on(:EDIT.l) }

    assert_selector("##{edit_pane_id}.collapse.in")
    assert_no_selector("##{view_pane_id}.in")

    # 2. Click Cancel — view pane reopens, edit pane collapses.
    within("##{edit_pane_id}") do
      find("a[href='##{view_pane_id}']").click
    end

    assert_selector("##{view_pane_id}.collapse.in")
    assert_no_selector("##{edit_pane_id}.in")

    # 3. Click "Edit" again — edit pane opens again.
    within("#notes_#{key_id}") { click_on(:EDIT.l) }

    assert_selector("##{edit_pane_id}.collapse.in")

    # 4. Change the notes and submit.
    within("#edit_api_key_#{key_id}_form") do
      fill_in("api_key_#{key_id}_notes",
              with: "Updated notes for accordion test")
      click_commit
    end

    # 5. After a successful submit, the view pane is back with the new notes.
    assert_selector("body.api_keys__index")
    assert_flash_success(:account_api_keys_updated.t.as_displayed)

    assert_selector("##{view_pane_id}.collapse.in")
    assert_no_selector("##{edit_pane_id}.in")
    assert_selector("#notes_#{key_id} span.current_notes",
                    text: "Updated notes for accordion test")
  end
end
