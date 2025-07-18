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
    title = :show_name_title.t(name: name.display_name)
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

  def test_name_pattern_search_with_near_miss_corrected
    near_miss_pattern = "agaricis campestrus"

    login
    visit("/")
    fill_in("search_pattern", with: near_miss_pattern)
    page.select("Names", from: :search_type)
    click_button("Search")

    assert_selector("#content div.alert-warning",
                    text: "Maybe you meant one of the following names?")

    corrected_pattern = "Agaricus"

    fill_in("search_pattern", with: corrected_pattern)
    page.select("Names", from: :search_type)
    click_button("Search")

    assert_no_selector("#content div.alert-warning")
    assert_selector("#title", text: :NAMES.l)
    assert_selector("#filters", text: corrected_pattern)
  end

  def test_name_pattern_search_with_old_provisional
    old_provisional = 'Cortinarius "sp-IN34"'

    login
    visit("/")
    fill_in("search_pattern", with: old_provisional)
    page.select("Names", from: :search_type)
    click_button("Search")

    assert_no_selector("#content div.alert-warning")
    title = CGI.unescapeHTML(
      "Mushroom Observer: Name: #{names(:provisional_name).text_name}".t
    )
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
