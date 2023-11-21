# frozen_string_literal: true

require("application_system_test_case")

class ObservationShowSystemTest < ApplicationSystemTestCase
  def test_add_and_edit_collection_number
    obs = observations(:peltigera_obs)

    # browser = page.driver.browser
    rolf = users("rolf")
    login!(rolf)

    assert_link("Your Observations")
    click_on("Your Observations")
    # obs = observations(:peltigera_obs)

    assert_selector("body.observations__index")
    assert_link(text: /Peltigera/)
    click_link(text: /Peltigera/)
    assert_selector("body.observations__show")

    assert_link(:create_collection_number.l)
    find(:css, ".new_collection_number_link").trigger("click")

    assert_selector("#modal_collection_number")

    within("#modal_collection_number") do
      assert_field("collection_number_number")
      fill_in("collection_number_number", with: "02134")
      click_commit
    end
    assert_no_selector("#modal_collection_number")

    c_n = CollectionNumber.last

    within("#observation_collection_numbers") do
      assert_link(text: /02134/)
      assert_link(:edit_collection_number.l)
      find(:css, ".edit_collection_number_link_#{c_n.id}").trigger("click")
    end

    assert_selector("#modal_collection_number")

    within("#modal_collection_number") do
      assert_field("collection_number_number")
      fill_in("collection_number_number", with: "021345")
      click_commit
    end
    assert_no_selector("#modal_collection_number")

    within("#observation_collection_numbers") do
      assert_link(text: /021345/)
    end

    assert_equal(c_n.reload.number, "021345")

    # Has a fungarium record: :field_museum_record
    fmr = herbarium_records(:field_museum_record)
    within("#observation_herbarium_records") do
      assert_link(text: /#{fmr.accession_number}/)
      assert_link(:edit_herbarium_record.l)
      find(:css, ".edit_herbarium_record_link_#{fmr.id}").trigger("click")
    end

    assert_selector("#modal_herbarium_record")

    within("#modal_herbarium_record") do
      assert_field("herbarium_record_accession_number")
      fill_in("herbarium_record_accession_number", with: "6234234")
      click_commit
    end
    assert_no_selector("#modal_herbarium_record")

    within("#observation_herbarium_records") do
      assert_link(text: /6234234/)
    end

    # new sequence
    assert_link(:show_observation_add_sequence.l)
    find(:css, ".new_sequence_link").trigger("click")

    assert_selector("#modal_sequence")
    within("#modal_sequence") do
      assert_field("sequence_locus")
      assert_field("sequence_bases")
      assert_select("sequence_archive")
      assert_field("sequence_accession")
      assert_field("sequence_notes")
      fill_in("sequence_locus", with: "LSU")
      fill_in("sequence_bases", with: "not quite there")
      select("UNITE", from: "sequence_archive")
      fill_in("sequence_accession", with: "323232")
      click_commit
    end

    assert_selector("#modal_sequence_flash")
    within("#modal_sequence_flash") do
      assert_selector("#flash_notices", text: /invalid code/)
    end

    bfs = sequences(:bare_formatted_sequence)

    within("#modal_sequence") do
      fill_in("sequence_bases", with: bfs.bases)
      click_commit
    end
    assert_no_selector("#modal_sequence")

    # edit sequence
    seq = Sequence.last
    within("#observation_sequences") do
      assert_link(text: /LSU/)
      assert_link(:EDIT.t)
      find(:css, ".edit_sequence_link_#{seq.id}").trigger("click")
    end

    within("#modal_sequence") do
      fill_in("sequence_notes", with: "Oh yea.")
      click_commit
    end
    assert_equal(seq.reload.notes, "Oh yea.")

    # new external link
    site = external_sites(:mycoportal)
    within("#observation_external_links") do
      assert_link(text: :ADD.l)
      find(:css, ".new_external_link_link_#{site.id}").trigger("click")
    end

    assert_selector("#modal_external_link")
    within("#modal_external_link") do
      assert_field("external_link_url")
      fill_in("external_link_url", with: "https://wedont.validatethese.urls")
      click_commit
    end
    assert_no_selector("#modal_external_link")

    # edit external link
    link = ExternalLink.last
    within("#observation_external_links") do
      assert_link(text: /MycoPortal/)
      assert_link(text: :EDIT.l)
      find(:css, ".edit_external_link_link_#{link.id}").trigger("click")
    end

    within("#modal_external_link") do
      assert_field("external_link_url")
      fill_in("external_link_url",
              with: "https://wedont.validatethese.urls/yet")
      click_commit
    end
    assert_no_selector("#modal_external_link")
    assert_equal(link.reload.url, "https://wedont.validatethese.urls/yet")

    # add destroys
  end

  def test_add_and_edit_naming
    obs = observations(:coprinus_comatus_obs)

    browser = page.driver.browser
    rolf = users("rolf")
    login!(rolf)

    assert_link("Your Observations")
    click_on("Your Observations")
    # obs = observations(:peltigera_obs)

    assert_selector("body.observations__index")
    assert_link(text: /#{obs.text_name}/)
    click_link(text: /#{obs.text_name}/)
    assert_selector("body.observations__show")
    assert_selector("#observation_namings")

    # new naming
    within("#observation_namings") do
      assert_link(text: /Propose/)
      find(:css, ".new_naming_link_#{obs.id}").trigger("click")
    end

    n_d = names(:namings_deprecated)
    nd1 = names(:namings_deprecated_1)

    assert_selector("#modal_naming")
    within("#modal_naming") do
      assert_field("naming_name")
      fill_in("naming_name", with: nd1.text_name)
      click_commit
    end
    assert_selector("#modal_naming_flash", text: /Missing/)
    assert_selector("#name_messages", text: /deprecated/)

    within("#modal_naming") do
      fill_in("naming_name", with: n_d.text_name)
      assert_selector(".auto_complete")
      browser.keyboard.type(:down, :tab)
      assert_no_selector(".auto_complete")
      click_commit
    end
    assert_no_selector("#modal_naming")

    nam = Naming.last
    assert_equal(n_d.text_name, nam.text_name)
    within("#observation_namings") do
      assert_link(text: /#{n_d.text_name}/)
      assert_selector("form#naming_vote_form_#{nam.id}")
      select("Could Be", from: "vote_value_#{nam.id}")
    end
    assert_selector("#title", text: /#{obs.text_name}/)

    within("#observation_namings") do
      assert_link(text: /#{n_d.text_name}/)
      assert_selector("form#naming_vote_form_#{nam.id}")
      select("I'd Call It That", from: "vote_value_#{nam.id}")
    end
    assert_selector("#title", text: /#{nam.text_name}/)

    # delete the alternate
    scroll_to("#observation_namings")

    within("#observation_namings") do
      assert_link(text: /#{n_d.text_name}/)
      assert_selector(".destroy_naming_link_#{nam.id}")
      find(:css, ".destroy_naming_link_#{nam.id}").trigger("click")
      assert_no_link(text: /#{n_d.text_name}/)
    end
    assert_selector("#title", text: /#{obs.text_name}/)
  end

  def test_add_and_edit_comment; end
end
