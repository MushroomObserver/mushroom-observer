# frozen_string_literal: true

require("test_helper")

# Test a few representative sessions of a power-user.
class ExpertTest < IntegrationTestCase
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
    get("/species_lists/new")
    member_notes = "Member notes."
    open_form("#species_list_form") do |form|
      form.assert_value("list_members", "")
      form.change("list_members", list)
      form.change("title", "List Title")
      form.change("place_name", albion_name_reverse)
      form.change("species_list_notes", "List notes.")
      form.change(SpeciesList.notes_part_id(Observation.other_notes_part),
                  member_notes)
      form.check("member_is_collection_location")
      form.check("member_specimen")
      form.submit
    end
    assert_flash_error
    assert_response(:success)
    assert_template("species_lists/new")

    assert_select("#missing_names", /Caloplaca arnoldii ssp. obliterate/)
    assert_select("#deprecated_names", /Lactarius alpigenes/)
    assert_select("#deprecated_names", /Lactarius alpinus/)
    assert_select("#deprecated_names", /Petigera/)
    assert_select("#deprecated_names", /Peltigera/)
    assert_select("#ambiguous_names", /Amanita baccata.*sensu Arora/)
    assert_select("#ambiguous_names", /Amanita baccata.*sensu Borealis/)
    assert_select("#ambiguous_names", /Suillus.*Gray/)
    assert_select("#ambiguous_names", /Suillus.*White/)

    # Fix the ambiguous names: should be good now.
    open_form("#species_list_form") do |form|
      assert_equal(list.split("\r\n").sort,
                   form.get_value!("list_members").split("\r\n").sort)
      form.check(
        /chosen_multiple_names_\d+_#{names(:amanita_baccata_arora).id}/
      )
      form.check(/chosen_multiple_names_\d+_#{names(:suillus_by_white).id}/)
      form.assert_checked("member_is_collection_location")
      form.assert_checked("member_specimen")
      form.submit
    end
    assert_flash_success
    assert_template("species_lists/show")

    spl = SpeciesList.last
    obs = spl.observations
    assert_equal(5, obs.length, obs.map(&:text_name).inspect)
    assert_equal([
      "Peltigera (Old) New Auth.", # (spelling corrected automatically)
      "Lactarius alpigenes Kühn.",
      "Suillus E.B. White",
      "Amanita baccata sensu Arora",
      "Caloplaca arnoldii subsp. obliterate"
    ].sort, obs.map(&:name).map(&:search_name).sort)
    assert_equal("List Title", spl.title)
    assert_equal(albion, spl.location)
    assert_equal("List notes.", spl.notes.strip)
    assert_equal(albion, obs.last.location)
    assert_equal(member_notes,
                 obs.last.notes[Observation.other_notes_key].strip)
    assert_true(obs.last.is_collection_location)
    assert_true(obs.last.specimen)

    # Try making some edits, too.
    click_mo_link(href: /#{edit_species_list_path(spl.id)}/)
    new_member_notes = "New member notes."
    open_form("#species_list_form") do |form|
      form.assert_value("list_members", "")
      form.assert_value("title", "List Title")
      form.assert_value("place_name", albion_name_reverse)
      form.assert_value("species_list_notes", "List notes.")
      form.assert_value(SpeciesList.notes_part_id(Observation.other_notes_part),
                        "Member notes.")
      form.assert_checked("member_is_collection_location", true)
      form.assert_checked("member_specimen", true)
      form.change("list_members", "Agaricus nova\r\nAmanita baccata\r\n")
      form.change("title", "Something New")
      form.change("place_name", new_location_reverse)
      form.change("species_list_notes", "New list notes.")
      form.change(SpeciesList.notes_part_id(Observation.other_notes_part),
                  new_member_notes)
      form.uncheck("member_is_collection_location")
      form.uncheck("member_specimen")
      form.submit
    end
    assert_flash_error
    assert_response(:success)
    assert_template("species_lists/edit")

    assert_select("#missing_names", /Agaricus nova/)
    assert_select("#ambiguous_names", /Amanita baccata.*sensu Arora/)
    assert_select("#ambiguous_names", /Amanita baccata.*sensu Borealis/)

    # Fix the ambiguous name.
    open_form("#species_list_form") do |form|
      form.check(/chosen_multiple_names_\d+_#{amanita[1].id}/)
      form.submit
    end
    assert_flash_success
    assert_template("locations/new")

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
    ].sort, obs.map(&:name).map(&:search_name).sort)
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
    open_form("#location_form") do |form|
      form.assert_value("location_display_name", new_location_reverse)
      form.change("location_display_name", newer_location_reverse)
      form.change("location_north", "35.6622")
      form.change("location_south", "35.6340")
      form.change("location_east", "-83.0371")
      form.change("location_west", "-83.0745")
      form.submit
    end
    assert_flash_success
    assert_template("species_lists/show")
    assert_select("#title", text: /#{spl.title}/)
    assert_select("a[href*=?]", edit_species_list_path(spl.id), text: /edit/i)

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

    # Try adding a comment, just for kicks.
    click_mo_link(href: /#{new_comment_path}/)
    assert_template("comments/new")
    assert_select("#title", text: /#{spl.title}/)
    assert_select("a[href*='species_lists/#{spl.id}']", text: /cancel/i)
    open_form("#comment_form") do |form|
      form.change("comment_summary", "Slartibartfast")
      form.change("comment_comment", "Steatopygia")
      form.submit
    end
    assert_flash_success
    assert_template("species_lists/show")
    assert_select("#title", text: /#{spl.title}/)
    assert_select("div.comment", text: /Slartibartfast/)
    assert_select("div.comment", text: /Steatopygia/)
  end
end
