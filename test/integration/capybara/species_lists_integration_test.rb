# frozen_string_literal: true

require("test_helper")

# Test a few representative sessions of a power-user.
class SpeciesListsIntegrationTest < CapybaraIntegrationTestCase
  def empty_notes
    NameDescription.all_note_fields.index_with { |_f| nil }
  end

  # ----------------------------------------------------------
  #  Test passing of arguments around in species list forms.
  # ----------------------------------------------------------

  def test_species_list_forms
    names = [
      "Petigera",
      "Lactarius alpigenes",
      "Suillus",
      "Amanita baccata",
      "Caloplaca arnoldii ssp. obliterate"
    ]
    list = names.join("\r\n")

    amanita = Name.where(text_name: "Amanita baccata")

    albion = locations(:albion)
    albion_name_reverse = Location.reverse_name(albion.name)

    new_location = "Somewhere New, California, USA"
    new_location_reverse = "USA, California, Somewhere New"

    newer_location = "Somewhere Else, California, USA"
    newer_location_reverse = "USA, California, Somewhere Else"

    # Good opportunity to test scientific location notation!
    dick.location_format = "scientific"
    dick.save

    # First attempt at creating a list.
    login!(dick)
    visit("/species_lists/new")
    assert_selector("body.species_lists__new")

    member_notes = "Member notes."
    within("#species_list_form") do
      assert_field("list_members", text: "")
      fill_in("list_members", with: list)
      fill_in("species_list_title", with: "List Title")
      fill_in("species_list_place_name", with: albion_name_reverse)
      fill_in("species_list_notes", with: "List notes.")
      fill_in(SpeciesList.notes_part_id(Observation.other_notes_part),
              with: member_notes)
      check("member_is_collection_location")
      check("member_specimen")
      click_commit
    end
    assert_flash_error
    assert_selector("body.species_lists__create")

    assert_selector("#missing_names",
                    text: /Caloplaca arnoldii ssp. obliterate/)
    assert_selector("#deprecated_names", text: /Lactarius alpigenes/)
    assert_selector("#deprecated_names", text: /Lactarius alpinus/)
    assert_selector("#deprecated_names", text: /Petigera/)
    assert_selector("#deprecated_names", text: /Peltigera/)
    assert_selector("#ambiguous_names",
                    text: /Amanita baccata.*sensu Arora/)
    assert_selector("#ambiguous_names",
                    text: /Amanita baccata.*sensu Borealis/)
    assert_selector("#ambiguous_names", text: /Suillus.*Gray/)
    assert_selector("#ambiguous_names", text: /Suillus.*White/)

    # Fix the ambiguous names: should be good now.
    # list_members is an autocompleter!
    within("#species_list_form") do
      assert_equal(list.split("\r\n").sort,
                   find("#list_members").text.split("\r ").sort)
      choose(id:
        /chosen_multiple_names_\d+_#{names(:amanita_baccata_arora).id}/)
      choose(id: /chosen_multiple_names_\d+_#{names(:suillus_by_white).id}/)
      assert_checked_field("member_is_collection_location")
      assert_checked_field("member_specimen")
      click_commit
    end
    assert_flash_success
    assert_selector("body.species_lists__show")

    spl = SpeciesList.last
    obs = spl.observations
    assert_equal(5, obs.length, obs.map(&:text_name).inspect)
    assert_equal([
      "Peltigera (Old) New Auth.", # (spelling corrected automatically)
      "Lactarius alpigenes Kühn.",
      "Suillus E.B. White",
      "Amanita baccata sensu Arora",
      "Caloplaca arnoldii subsp. obliterate"
    ].sort, obs.map { |o| o.name.search_name }.sort)
    assert_equal("List Title", spl.title)
    assert_equal(albion, spl.location)
    assert_equal("List notes.", spl.notes.strip)
    assert_equal(albion, obs.last.location)
    assert_equal(member_notes,
                 obs.last.notes[Observation.other_notes_key].strip)
    assert_true(obs.last.is_collection_location)
    assert_true(obs.last.specimen)

    # Try making some edits, too.
    first(:link, href: /#{edit_species_list_path(spl.id)}/).click
    assert_selector("body.species_lists__edit")

    new_member_notes = "New member notes."
    within("#species_list_form") do
      assert_field("list_members", text: "")
      assert_field("species_list_title", with: "List Title")
      assert_field("species_list_place_name", with: albion_name_reverse)
      assert_field("species_list_notes", with: "List notes.")
      assert_field(SpeciesList.notes_part_id(Observation.other_notes_part),
                   with: "Member notes.")
      assert_checked_field("member_is_collection_location")
      assert_checked_field("member_specimen")
      fill_in("list_members", with: "Agaricus nova\r\nAmanita baccata\r\n")
      fill_in("species_list_title", with: "Something New")
      fill_in("species_list_place_name", with: new_location_reverse)
      fill_in("species_list_notes", with: "New list notes.")
      fill_in(SpeciesList.notes_part_id(Observation.other_notes_part),
              with: new_member_notes)
      uncheck("member_is_collection_location")
      uncheck("member_specimen")
      click_commit
    end
    assert_flash_error
    assert_selector("body.species_lists__update")

    assert_selector("#missing_names", text: /Agaricus nova/)
    assert_selector("#ambiguous_names", text: /Amanita baccata.*sensu Arora/)
    assert_selector("#ambiguous_names", text: /Amanita baccata.*sensu Borealis/)

    # Fix the ambiguous name.
    within("#species_list_form") do
      choose(id: /chosen_multiple_names_\d+_#{amanita[1].id}/)
      click_commit
    end
    assert_flash_success
    assert_selector("body.locations__new")

    spl.reload
    obs = spl.observations
    assert_equal(7, obs.length, obs.map(&:text_name).inspect)
    assert_equal([
      "Peltigera (Old) New Auth.",
      "Lactarius alpigenes Kühn.",
      "Suillus E.B. White",
      "Amanita baccata sensu Arora",
      "Caloplaca arnoldii subsp. obliterate",
      "Agaricus nova",
      "Amanita baccata sensu Borealis"
    ].sort, obs.map { |o| o.name.search_name }.sort)
    assert_equal("Something New", spl.title)
    assert_equal(new_location, spl.where)
    assert_nil(spl.location)
    assert_equal("New list notes.", spl.notes.strip)
    assert_nil(obs.last.location)
    assert_equal(new_location, obs.last.where)
    assert_nil(obs.last.location)
    assert_equal(new_member_notes,
                 obs.last.notes[Observation.other_notes_key].strip)
    assert_false(obs.last.is_collection_location)
    assert_false(obs.last.specimen)

    # Should have chained us into create_location.  Define this location
    # and make sure it updates both the observations and the list.
    within("#location_form") do
      assert_field("location_display_name", with: new_location_reverse)
      fill_in("location_display_name", with: newer_location_reverse)
      fill_in("location_north", with: "35.6622")
      fill_in("location_south", with: "35.6340")
      fill_in("location_east", with: "-83.0371")
      fill_in("location_west", with: "-83.0745")
      click_commit
    end
    assert_flash_success
    assert_selector("body.species_lists__show")
    assert_selector("#title", text: /#{spl.title}/)
    assert_link(href: edit_species_list_path(spl.id))

    loc = Location.last
    assert_equal(newer_location, loc.name)
    assert_equal(dick, User.current)
    assert_equal(newer_location_reverse, loc.display_name)
    spl.reload
    obs = spl.observations
    assert_equal(loc.name, spl.where)
    assert_equal(loc, spl.location)
    assert_equal(loc.name, obs.last.where)
    assert_equal(loc, obs.last.location)

    # Try adding a comment, just for kicks. This will hit HTML, not Turbo
    click_link(href: /#{new_comment_path}/)
    assert_selector("body.comments__new")
    assert_selector("#title", text: /#{spl.title}/)
    assert_selector("a[href*='species_lists/#{spl.id}']", text: /cancel/i)
    within("#comment_form") do
      fill_in("comment_summary", with: "Slartibartfast")
      fill_in("comment_comment", with: "Steatopygia")
      click_commit
    end
    assert_flash_success
    assert_selector("body.species_lists__show")
    assert_selector("#title", text: /#{spl.title}/)
    assert_selector(".comment", text: /Slartibartfast/)
    assert_selector(".comment", text: /Steatopygia/)
  end
end
