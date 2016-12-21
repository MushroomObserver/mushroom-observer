# encoding: utf-8

# Test a few representative sessions of a power-user.

require "test_helper"

class ExpertTest < IntegrationTestCase
  def empty_notes
    hash = {}
    for f in NameDescription.all_note_fields
      hash[f] = nil
    end
    hash
  end

  # --------------------------------------------------------
  #  Test passing of arguments around in bulk name editor.
  # --------------------------------------------------------

  def test_bulk_name_editor
    name1 = "Caloplaca arnoldii"
    author1 = "(Wedd.) Zahlbr."
    full_name1 = "#{name1} #{author1}"

    name2 = "Caloplaca arnoldii ssp. obliterate"
    author2 = "(Pers.) Gaya"
    full_name2 = "#{name1} #{author2}"

    name3 = "Acarospora nodulosa var. reagens"
    author3 = "Zahlbr."
    full_name3 = "#{name1} #{author3}"

    name4 = "Lactarius subalpinus"
    name5 = "Lactarius newname"

    list =
      "#{name1} #{author1}\r\n" \
      "#{name2} #{author2}\r\n" \
      "#{name3} #{author3}\r\n" \
      "#{name4} = #{name5}"

    sess = login!(dick)
    sess.get("/name/bulk_name_edit")
    sess.open_form do |form|
      form.assert_value("list_members", "")
      form.change("list_members", list)
      form.submit
    end
    sess.assert_flash_error
    sess.assert_response(:success)
    sess.assert_template("name/bulk_name_edit")

    # Don't mess around, just let it do whatever it does, and make sure it is
    # correct.  I don't want to make any assumptions about how the internals
    # work (e.g., I don't want to make any assertions about the hidden fields)
    # -- all I want to be sure of is that it doesn't mess up our list of names.
    sess.open_form do |form|
      assert_equal(list.split(/\r\n/).sort,
                   form.get_value!("list_members").split(/\r\n/).sort)
      # field = form.get_field('approved_names')
      form.submit
    end
    sess.assert_flash_success
    sess.assert_template("observer/list_rss_logs")

    assert_not_nil(Name.find_by_text_name("Caloplaca"))

    names = Name.where(text_name: name1)
    assert_equal(1, names.length, names.map(&:search_name).inspect)
    assert_equal(author1, names.first.author)
    assert_equal(false, names.first.deprecated)

    names = Name.where(text_name: name2.sub(/ssp/, "subsp"))
    assert_equal(1, names.length, names.map(&:search_name).inspect)
    assert_equal(author2, names.first.author)
    assert_equal(false, names.first.deprecated)

    names = Name.where(text_name: name2.sub(/ssp/, "subsp"))
    assert_equal(1, names.length, names.map(&:search_name).inspect)
    assert_equal(author2, names.first.author)
    assert_equal(false, names.first.deprecated)

    assert_not_nil(Name.find_by_text_name("Acarospora"))
    assert_not_nil(Name.find_by_text_name("Acarospora nodulosa"))

    names = Name.where(text_name: name3)
    assert_equal(1, names.length, names.map(&:search_name).inspect)
    assert_equal(author3, names.first.author)
    assert_equal(false, names.first.deprecated)

    names = Name.where(text_name: name4)
    assert_equal(1, names.length, names.map(&:search_name).inspect)
    assert_equal(false, names.first.deprecated)

    names = Name.where(text_name: name5)
    assert_equal(1, names.length, names.map(&:search_name).inspect)
    assert_equal("", names.first.author)
    assert_equal(true, names.first.deprecated)

    # I guess this is left alone, even though you would probably
    # expect it to be deprecated.
    names = Name.where(text_name: "Lactarius alpinus")
    assert_equal(1, names.length, names.map(&:search_name).inspect)
    assert_equal(false, names.first.deprecated)
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
    albion_name = albion.name
    albion_name_reverse = Location.reverse_name(albion.name)

    new_location = "Somewhere New, California, USA"
    new_location_reverse = "USA, California, Somewhere New"

    newer_location = "Somewhere Else, California, USA"
    newer_location_reverse = "USA, California, Somewhere Else"

    # Good opportunity to test scientific location notation!
    dick.location_format = :scientific
    dick.save

    # First attempt at creating a list.
    sess = login!(dick)
    sess.get("/species_list/create_species_list")
    sess.open_form do |form|
      form.assert_value("list_members", "")
      form.change("list_members", list)
      form.change("title", "List Title")
      form.change("place_name", albion_name_reverse)
      form.change("species_list_notes", "List notes.")
      form.change("member_notes", "Member notes.")
      form.check("member_is_collection_location")
      form.check("member_specimen")
      form.submit
    end
    sess.assert_flash_error
    sess.assert_response(:success)
    sess.assert_template("species_list/create_species_list")

    sess.assert_select('div#missing_names', /Caloplaca arnoldii ssp. obliterate/)
    sess.assert_select('div#deprecated_names', /Lactarius alpigenes/)
    sess.assert_select('div#deprecated_names', /Lactarius alpinus/)
    sess.assert_select('div#deprecated_names', /Petigera/)
    sess.assert_select('div#deprecated_names', /Peltigera/)
    sess.assert_select('div#ambiguous_names', /Amanita baccata.*sensu Arora/)
    sess.assert_select('div#ambiguous_names', /Amanita baccata.*sensu Borealis/)
    sess.assert_select('div#ambiguous_names', /Suillus.*Gray/)
    sess.assert_select('div#ambiguous_names', /Suillus.*White/)

    # Fix the ambiguous names: should be good now.
    sess.open_form do |form|
      assert_equal(list.split(/\r\n/).sort,
                   form.get_value!("list_members").split(/\r\n/).sort)
      form.check(/chosen_multiple_names_\d+_#{names(:amanita_baccata_arora).id}/)
      form.check(/chosen_multiple_names_\d+_#{names(:suillus_by_white).id}/)

      # For some reason these need to be explicitly re-checked
      form.assert_value("member_is_collection_location", false) # Should be true
      form.assert_value("member_specimen", false) # Should be true
      form.check("member_is_collection_location")
      form.check("member_specimen")

      form.submit
    end
    sess.assert_flash_success
    sess.assert_template("species_list/show_species_list")

    spl = SpeciesList.last
    obs = spl.observations
    assert_equal(5, obs.length, obs.map(&:text_name).inspect)
    assert_equal([
      "Petigera",
      "Lactarius alpigenes Kühn.",
      "Suillus E.B. White",
      "Amanita baccata sensu Arora",
      "Caloplaca arnoldii subsp. obliterate"
    ].sort, obs.map(&:name).map(&:search_name).sort)
    assert_equal("List Title", spl.title)
    assert_equal(albion, spl.location)
    assert_equal("List notes.", spl.notes.strip)
    assert_equal(albion, obs.last.location)
    assert_equal("Member notes.", obs.last.notes.strip)
    assert_true(obs.last.is_collection_location)
    assert_true(obs.last.specimen)

    # Try making some edits, too.
    sess.click(href: /edit_species_list/)
    sess.open_form do |form|
      form.assert_value("list_members", "")
      form.assert_value("title", "List Title")
      form.assert_value("place_name", albion_name_reverse)
      form.assert_value("species_list_notes", "List notes.")
      form.assert_value("member_notes", "Member notes.")
      form.assert_value("member_is_collection_location", false) # Was true
      form.assert_value("member_specimen", false) # Was true
      form.change("list_members", "Agaricus nova\r\nAmanita baccata\r\n")
      form.change("title", "Something New")
      form.change("place_name", new_location_reverse)
      form.change("species_list_notes", "New list notes.")
      form.change("member_notes", "New member notes.")
      form.uncheck("member_is_collection_location")
      form.uncheck("member_specimen")
      form.submit
    end
    sess.assert_flash_error
    sess.assert_response(:success)
    sess.assert_template("species_list/edit_species_list")

    sess.assert_select('div#missing_names', /Agaricus nova/)
    sess.assert_select('div#ambiguous_names', /Amanita baccata.*sensu Arora/)
    sess.assert_select('div#ambiguous_names', /Amanita baccata.*sensu Borealis/)

    # Fix the ambiguous name.
    sess.open_form do |form|
      form.check(/chosen_multiple_names_\d+_#{amanita[1].id}/)
      form.submit
    end
    sess.assert_flash_success
    sess.assert_template("location/create_location")

    spl.reload
    obs = spl.observations
    assert_equal(7, obs.length, obs.map(&:text_name).inspect)
    assert_equal([
      "Petigera",
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
    assert_equal("New member notes.", obs.last.notes.strip)
    assert_false(obs.last.is_collection_location)
    assert_false(obs.last.specimen)

    # Should have chained us into create_location.  Define this location
    # and make sure it updates both the observations and the list.
    sess.open_form do |form|
      form.assert_value("location_display_name", new_location_reverse)
      form.change("location_display_name", newer_location_reverse)
      form.change("location_north", "35.6622")
      form.change("location_south", "35.6340")
      form.change("location_east", "-83.0371")
      form.change("location_west", "-83.0745")
      form.submit
    end
    sess.assert_flash_success
    sess.assert_template("species_list/show_species_list")
    sess.assert_select('div#title', text: /#{spl.title}/)
    sess.assert_select("a[href*='edit_species_list/#{spl.id}']", text: /edit/i)

    loc = Location.last
    assert_equal(newer_location, loc.name)
    assert_equal(dick, User.current)
    assert_equal(newer_location_reverse, loc.display_name)
    spl.reload
    obs = spl.observations
    assert_nil(spl.where)
    assert_equal(loc, spl.location)
    assert_nil(obs.last.where)
    assert_equal(loc, obs.last.location)

    # Try adding a comment, just for kicks.
    sess.click(href: /add_comment/)
    sess.assert_template("comment/add_comment")
    sess.assert_select('div#title', text: /#{spl.title}/)
    sess.assert_select("a[href*='show_species_list/#{spl.id}']", text: /cancel/i)
    sess.open_form do |form|
      form.change("comment_summary", "Slartibartfast")
      form.change("comment_comment", "Steatopygia")
      form.submit
    end
    sess.assert_flash_success
    sess.assert_template("species_list/show_species_list")
    sess.assert_select('div#title', text: /#{spl.title}/)
    sess.assert_select("div.comment", text: /Slartibartfast/)
    sess.assert_select("div.comment", text: /Steatopygia/)
  end
end
