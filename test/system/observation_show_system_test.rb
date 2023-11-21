# frozen_string_literal: true

require("application_system_test_case")

class ObservationShowSystemTest < ApplicationSystemTestCase
  # regularize link class names
  def test_add_and_edit_collection_number
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

    sit = external_sites(:mycoportal)

    within("#observation_external_links") do
      assert_link(text: :ADD.l)
      find(:css, ".new_external_link_link_#{sit.id}").trigger("click")
    end

    assert_selector("#modal_external_link")

    within("#modal_external_link") do
      assert_field("url")
      fill_in("url", with: "https://wedont.validatethese.urls/yet")
      click_commit
    end
    assert_no_selector("#modal_external_link")

    within("#observation_external_links") do
      assert_link(text: /MycoPortal/)
    end

    # script = <<-JS
    # var button = document.getElementById("button_toggle_answered_1")
    # button.click();
    # JS
    # page.execute_script(script)
  end

  def test_add_and_edit_naming
  end

  def test_add_and_edit_naming_vote
  end

  def test_add_and_edit_comment
  end
end
