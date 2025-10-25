# frozen_string_literal: true

require("test_helper")

# Test a few representative sessions of a power-user.
class SpeciesListsIntegrationTest < CapybaraIntegrationTestCase
  def empty_notes
    NameDescription.all_note_fields.index_with { |_f| nil }
  end

  # ----------------------------------------------------------
  #  Test passing of arguments around in species_list forms.
  # ----------------------------------------------------------

  def test_species_list_forms
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

    # member_notes = "Member notes."
    within("#species_list_form") do
      fill_in("species_list_title", with: "List Title")
      fill_in("species_list_place_name", with: albion_name_reverse)
      fill_in("species_list_notes", with: "List notes.")
      click_commit
    end
    assert_flash_success
    assert_selector("body.species_lists__show")

    spl = SpeciesList.last
    assert_equal("List Title", spl.title)
    assert_equal(albion, spl.location)
    assert_equal("List notes.", spl.notes.strip)

    # Try making some edits, too.
    first(:link, href: /#{edit_species_list_path(spl.id)}/).click
    assert_selector("body.species_lists__edit")

    within("#species_list_form") do
      assert_field("species_list_title", with: "List Title")
      assert_field("species_list_place_name", with: albion_name_reverse)
      assert_field("species_list_notes", with: "List notes.")
      fill_in("species_list_title", with: "Something New")
      fill_in("species_list_place_name", with: new_location_reverse)
      fill_in("species_list_notes", with: "New list notes.")
      click_commit
    end
    assert_flash_success
    assert_selector("body.locations__new")

    spl.reload
    assert_equal("Something New", spl.title)
    assert_equal(new_location, spl.where)
    assert_nil(spl.location)
    assert_equal("New list notes.", spl.notes.strip)

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
    assert_equal(loc.name, spl.where)
    assert_equal(loc, spl.location)

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

  def test_add_remove_from_another_list
    spl = species_lists(:unknown_species_list)

    login
    visit(species_list_path(spl))
    first("a", text: :species_list_show_add_remove_from_another_list.l).click

    assert_match(
      species_lists_edit_observations_path, current_path,
      "Clicking #{:species_list_show_add_remove_from_another_list.l} " \
      "should go to #{:species_list_add_remove_title.l}"
    )
  end

  def test_species_list_write_in_forms
    names = [
      "Petigera",
      "Lactarius alpigenes",
      "Suillus",
      "Amanita baccata",
      "Caloplaca arnoldii ssp. obliterate"
    ]
    list = names.join("\r\n")

    Name.where(text_name: "Amanita baccata")

    albion = locations(:albion)
    Location.reverse_name(albion.name)

    # Good opportunity to test scientific location notation!

    # First attempt at creating a list.
    spl = species_lists(:first_species_list)
    user = spl.user
    user.location_format = "scientific"
    user.save
    login!(user)

    visit("/species_lists/#{spl.id}/write_in/new")
    assert_selector("body.write_in__new")

    member_notes = "Member notes."
    within("#species_list_write_in_form") do
      assert_field("list_members", text: "")
      fill_in("list_members", with: list)
      fill_in(SpeciesList.notes_part_id(Observation.other_notes_part),
              with: member_notes)
      check("member_is_collection_location")
      check("member_specimen")
      click_commit
    end
    assert_flash_error
    assert_selector("body.write_in__create")
  end
end
