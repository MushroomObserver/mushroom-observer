# frozen_string_literal: true

require("test_helper")

# Tests which supplement controller/name_controller_test.rb
class NamesIntegrationTest < CapybaraIntegrationTestCase
  def test_name_show_previous_version
    # a name with versions
    name = names(:coprinellus_micaceus)
    # current_version_number = name.version
    previous_version = name.versions.reverse[1]
    login
    visit("/names/#{name.id}")
    click_on(class: "previous_version_link")
    assert_selector("body.versions__show")
    title = :show_past_name_title.t(
      num: previous_version.version,
      name: previous_version.display_name
    )
    assert_selector("#title", text: title.as_displayed)
    # go back to the name page
    click_on(class: "latest_version_link")
    title = name.display_name.t
    assert_selector("#title", text: title.as_displayed)
  end

  # Email tracking template should not contain ":mailing_address"
  # because, when email is sent, that will be interpreted as
  # recipient's mailing_address
  def test_email_tracking_template_no_email_address_symbol
    login(rolf)

    visit("/names/#{names(:boletus_edulis).id}/trackers/new")
    template = find("#name_tracker_note_template")
    template.assert_no_text(":mailing_address")
  end

  def test_create_name_tracker
    name = names(:boletus_edulis)
    login(rolf)

    # Visit the new name tracker page
    visit("/names/#{name.id}/trackers/new")
    assert_selector("body.trackers__new")

    # Fill in the note template
    fill_in("name_tracker_note_template",
            with: "Test note about :observation")

    # Check the checkbox to enable note template
    page.check("name_tracker[note_template_enabled]")

    # Submit the form to the correct action
    within("form[action='/names/#{name.id}/trackers']") do
      click_button("Enable")
    end

    # Verify successful creation (redirects to name page)
    assert_selector("body.names__show")
    assert_current_path(name_path(name))

    # Verify database effect
    tracker = NameTracker.find_by(name: name, user: rolf)
    assert(tracker, "Tracker should have been created")
    assert_equal("Test note about :observation", tracker.note_template,
                 "Note template should be saved. Got: #{tracker.note_template.inspect}")
  end

  def test_update_name_tracker
    name = names(:coprinus_comatus)
    login(rolf)

    # Ensure tracker exists in fixtures or create it
    tracker = NameTracker.find_by(name: name, user: rolf)
    assert(tracker, "Tracker should exist for this test")

    # Visit the edit name tracker page
    visit("/names/#{name.id}/trackers/edit")
    assert_selector("body.trackers__edit")

    # Update the form
    fill_in("name_tracker_note_template", with: "Updated note about :observer")

    # Ensure checkbox is checked
    page.check("name_tracker[note_template_enabled]")

    # Submit the form to the correct action
    within("form[action='/names/#{name.id}/trackers']") do
      click_button("Update")
    end

    # Verify successful update
    assert_selector("body.names__show")
    assert_current_path(name_path(name))

    # Verify database effect
    tracker.reload
    assert_equal("Updated note about :observer", tracker.note_template)
  end

  def test_name_deprecation
    bad_name = names(:agaricus_campestros)
    good_name = names(:agaricus_campestris)
    assert_not(bad_name.deprecated)
    assert_not(good_name.deprecated)
    assert_nil(bad_name.synonym_id)
    assert_nil(good_name.synonym_id)

    login(rolf)
    visit("/names/#{bad_name.id}")

    # First deprecate bad_name.
    within("#nomenclature") { click_link(text: "Deprecate") }
    fill_in("proposed_name", with: good_name.text_name)
    fill_in("comment", with: "bad name")
    click_on("Submit")

    assert(bad_name.reload.deprecated)
    assert_not(good_name.reload.deprecated)
    assert_not_nil(bad_name.synonym_id)
    assert_equal(bad_name.synonym_id, good_name.synonym_id)
    comment = bad_name.comments.last
    assert_not_nil(comment)
    assert_equal("bad name", comment.comment)

    # Then undo it and approve it.
    within("#nomenclature") { click_link(text: "Approve") }
    page.uncheck("deprecate_others")
    fill_in("comment", with: "my bad")
    click_on("Approve")

    assert_not(bad_name.reload.deprecated)
    assert_not(good_name.reload.deprecated)
    assert_not_nil(bad_name.synonym_id)
    assert_equal(bad_name.synonym_id, good_name.synonym_id)
    comment = bad_name.comments.last
    assert_not_nil(comment)
    assert_equal("my bad", comment.comment)

    # But still need to undo the synonymy.
    within("#nomenclature") { click_link(text: "Change Synonyms") }
    click_on("Submit Changes")

    assert_not(bad_name.reload.deprecated)
    assert_not(good_name.reload.deprecated)
    assert_nil(bad_name.synonym_id)
    assert_nil(good_name.synonym_id)
  end

  def test_name_pattern_search_with_correctable_pattern
    correctable_pattern = "agaricis campestrus"

    login
    visit("/")
    fill_in("pattern_search_pattern", with: correctable_pattern)
    page.select("Names", from: :pattern_search_type)
    within("#pattern_search_form") { click_button("Search") }

    assert_selector("#content div.alert-warning",
                    text: "Maybe you meant one of the following names?")

    corrected_pattern = "Agaricus"
    name = names(:agaricus_campestris)
    assert_selector("#content a[href *= 'names/#{name.id}']",
                    text: name.search_name)
    assert_selector("#content div.alert-warning", text: corrected_pattern)

    fill_in("pattern_search_pattern", with: corrected_pattern)
    page.select("Names", from: :pattern_search_type)
    within("#pattern_search_form") { click_button("Search") }

    assert_no_selector("#content div.alert-warning")
    # assert_selector("#title", text: :NAMES.l)
    assert_selector("#filters", text: corrected_pattern)
  end

  def test_name_pattern_search_with_old_provisional
    old_provisional = 'Cortinarius "sp-IN34"'
    name = names(:provisional_name)
    login
    visit("/")
    fill_in("pattern_search_pattern", with: old_provisional)
    page.select("Names", from: :pattern_search_type)
    within("#pattern_search_form") { click_button("Search") }

    assert_no_selector("#content div.alert-warning")
    title =
      "Mushroom Observer: Name #{name.id}: #{name.user_display_name(rolf)}".
      t.as_displayed

    assert_title(title)
  end

  def test_lifeform_edit
    name = names(:tremella_celata)

    # make sure fixtures will work for this test
    assert(name.lifeform.blank?,
           "Test needs fixture without a lifeform")

    login
    visit(edit_lifeform_of_name_path(name))

    check("lifeform_lichenicolous")
    click_on(:SAVE.l)

    assert_equal(" lichenicolous ", name.reload.lifeform,
                 "Failed to update lifeform")
  end

  def test_lifeform_propagate
    genus = names(:tremella)
    species = names(:tremella_celata)

    # make sure fixtures will work for this test
    assert(genus.children.include?(species))
    assert(genus.lifeform.present? && species.lifeform.blank?,
           "Test needs fixtures where genus has lifeform but species does not")
    assert_match(/#{:lifeform_lichenicolous.l}/i, genus.lifeform)

    login
    visit(name_path(genus))
    within("#name_lifeform") do
      click_on(:show_name_propagate_lifeform.l)
    end

    check("add_lichenicolous")
    click_on(:APPLY.l)

    assert_equal(genus.lifeform, species.reload.lifeform,
                 "Failed to propogate lifeform to subtaxon")
  end
end
