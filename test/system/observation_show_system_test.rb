# frozen_string_literal: true

require("application_system_test_case")

class ObservationShowSystemTest < ApplicationSystemTestCase
  setup do
    @obs = observations(:peltigera_obs)
  end

  def test_visit_show_observation
    # # browser = page.driver.browser
    rolf = users("rolf")
    login!(rolf)

    assert_link("Your Observations")
    click_on("Your Observations")

    assert_selector("body.observations__index")
    assert_link(text: /#{@obs.text_name}/)
    click_link(text: /#{@obs.text_name}/)
    assert_selector("body.observations__show")

    assert_selector(".print_label_observation_#{@obs.id}")
  end

  def test_add_and_edit_collection_numbers
    rolf = users("rolf")
    login!(rolf)
    visit(observation_path(@obs))
    assert_selector("body.observations__show")

    scroll_to(find("#observation_collection_numbers"), align: :center)
    within("#observation_collection_numbers") do
      assert_link(:create_collection_number.l)
      # Link is too small to click normally, use trigger
      find_link(:create_collection_number.l).trigger("click")
    end

    assert_selector("#modal_collection_number", wait: 6)

    # Generate unique collection number and name using timestamp
    timestamp = Time.now.to_i
    unique_number = "TEST-#{timestamp}"
    unique_name = "TestCollector-#{timestamp}"

    # Test validation - submit without required collector name
    within("#modal_collection_number") do
      assert_field("collection_number_name")
      assert_field("collection_number_number")
      fill_in("collection_number_name", with: "") # Explicitly clear
      fill_in("collection_number_number", with: unique_number)
      click_commit
    end
    sleep(1) # Give turbo time to process

    # Modal should stay open with validation error
    assert_selector("#modal_collection_number")
    within("#modal_collection_number") do
      assert_text(/missing|required/i)
    end

    # Now fill in the missing name and resubmit
    within("#modal_collection_number") do
      fill_in("collection_number_name", with: unique_name)
      click_commit
    end
    sleep(1)

    # Modal should close after successful submission
    assert_no_selector("#modal_collection_number")

    c_n = CollectionNumber.last

    within("#observation_collection_numbers") do
      assert_link(text: /#{unique_number}/)
      assert_link(:edit_collection_number.l)
      find_link(:edit_collection_number.l).trigger("click")
    end

    assert_selector("#modal_collection_number_#{c_n.id}", wait: 6)

    # Edit to a new unique number
    updated_number = "#{unique_number}-UPDATED"
    within("#modal_collection_number_#{c_n.id}") do
      assert_field("collection_number_number")
      fill_in("collection_number_number", with: updated_number)
      click_commit
    end
    assert_no_selector("#modal_collection_number_#{c_n.id}")

    within("#observation_collection_numbers") do
      assert_link(text: /#{updated_number}/)
    end

    assert_equal(c_n.reload.number, updated_number)

    # try remove links
    # collection_number
    within("#observation_collection_numbers") do
      assert_link(:REMOVE.l)
      find(:css, ".remove_collection_number_link_#{c_n.id}").trigger("click")
    end
    # confirm is in modal
    assert_selector("#modal_collection_number_observation")
    within("#modal_collection_number_observation") do
      assert_button(:REMOVE.l)
      find(:css, ".remove_collection_number_link_#{c_n.id}").trigger("click")
    end
    assert_no_selector("#modal_collection_number_observation")
    assert_no_link(text: /#{updated_number}/)
  end

  def test_add_and_edit_herbarium_records
    rolf = users("rolf")
    login!(rolf)
    visit(observation_path(@obs))
    assert_selector("body.observations__show")

    # Has a fungarium record: :field_museum_record. Try edit
    fmr = herbarium_records(:field_museum_record)
    within("#observation_herbarium_records") do
      assert_link(text: /#{fmr.accession_number}/)
      assert_link(:edit_herbarium_record.l)
      find_link(:edit_herbarium_record.l).trigger("click")
    end

    assert_selector("#modal_herbarium_record_#{fmr.id}", wait: 6)

    # Edit herbarium record
    within("#modal_herbarium_record_#{fmr.id}") do
      # Verify herbarium name field exists
      assert_field("herbarium_record_herbarium_name")

      # Verify has_id_indicator (green check) exists (may not be visible yet)
      assert_selector(
        "span.has-id-indicator[data-autocompleter-target='hasIdIndicator']",
        visible: :all
      )

      # Edit accession number
      assert_field("herbarium_record_accession_number")
      fill_in("herbarium_record_accession_number", with: "6234234")
      click_commit
    end
    sleep(1)

    # Modal should close after successful submission
    assert_no_selector("#modal_herbarium_record_#{fmr.id}")

    within("#observation_herbarium_records") do
      assert_link(text: /6234234/)
    end

    # Test remove herbarium record
    within("#observation_herbarium_records") do
      # Verify remove link has text-danger class
      assert_selector("a.text-danger", text: :REMOVE.l)
      # Click the remove link
      find("a", text: :REMOVE.l).trigger("click")
    end

    # Modal should appear
    assert_selector("#modal_herbarium_record_observation", wait: 6)

    # Confirm removal in modal
    within("#modal_herbarium_record_observation") do
      assert_button(:REMOVE.l)
      find("button", text: :REMOVE.l).trigger("click")
    end
    sleep(1)

    # Modal should close and record should be removed from the list
    assert_no_selector("#modal_herbarium_record_observation")
    within("#observation_herbarium_records") do
      assert_no_link(text: /6234234/)
    end
  end

  def test_add_and_edit_sequences
    rolf = users("rolf")
    login!(rolf)
    visit(observation_path(@obs))
    assert_selector("body.observations__show")

    # new sequence
    assert_link(:show_observation_add_sequence.l)
    find_link(:show_observation_add_sequence.l).trigger("click")

    assert_selector("#modal_sequence", wait: 6)

    # Test validation - submit with invalid DNA sequence
    within("#modal_sequence") do
      assert_field("sequence_locus")
      assert_field("sequence_bases")
      assert_select("sequence_archive")
      assert_field("sequence_accession")
      assert_field("sequence_notes")
      fill_in("sequence_locus", with: "LSU")
      fill_in("sequence_bases", with: "not a valid DNA sequence")
      select("UNITE", from: "sequence_archive")
      fill_in("sequence_accession", with: "323232")
      click_commit
    end
    sleep(1)

    # Modal should stay open with validation error
    assert_selector("#modal_sequence")
    within("#modal_sequence") do
      assert_text(/invalid code/i)
    end

    # Now fix with valid DNA sequence and resubmit
    bfs = sequences(:bare_formatted_sequence)
    within("#modal_sequence") do
      fill_in("sequence_bases", with: bfs.bases)
      click_commit
    end
    sleep(1)

    # Modal should close after successful submission
    assert_no_selector("#modal_sequence")

    # edit sequence
    seq = Sequence.last
    within("#observation_sequences") do
      assert_link(text: /LSU/)
      assert_link(:EDIT.t)
      find(:css, ".edit_sequence_link_#{seq.id}").trigger("click")
    end

    within("#modal_sequence_#{seq.id}") do
      fill_in("sequence_notes", with: "Oh yea.")
      click_commit
    end
    assert_equal(seq.reload.notes, "Oh yea.")
    assert_no_selector("#modal_sequence_#{seq.id}")

    # try remove links
    # sequence
    within("#observation_sequences") do
      assert_button(:destroy_object.t(type: :sequence))
      accept_confirm do
        find(:css, ".destroy_sequence_link_#{seq.id}").trigger("click")
      end
      assert_no_link(text: /LSU/)
    end
  end

  def test_add_and_edit_external_links
    mary = users("mary")
    login!(mary)
    visit(observation_path(@obs))
    assert_selector("body.observations__show")

    # new external link
    site = external_sites(:mycoportal)
    within("#observation_external_links") do
      assert_link(text: :ADD.l)
      find_link(:ADD.l).trigger("click")
    end

    # Test validation - submit with invalid URL
    assert_selector("#modal_external_link")
    within("#modal_external_link") do
      assert_field("external_link_url")
      select(site.name, from: "external_link_external_site_id")
      fill_in("external_link_url", with: "not-a-valid-url")
      click_commit
    end
    sleep(1)

    # Modal should stay open with validation error
    assert_selector("#modal_external_link")
    within("#modal_external_link") do
      assert_text(/invalid/i)
    end

    # Now fix with valid URL and resubmit
    within("#modal_external_link") do
      fill_in("external_link_url", with: "https://www.mycoportal.org/portal/collections/123")
      click_commit
    end
    sleep(1)

    # Modal should close after successful submission
    assert_no_selector("#modal_external_link")

    # edit external link
    link = ExternalLink.last
    within("#observation_external_links") do
      assert_link(text: /MycoPortal/)
      assert_link(text: :EDIT.l)
      find_link(:EDIT.l).trigger("click")
    end

    within("#modal_external_link_#{link.id}") do
      assert_field("external_link_url")
      fill_in("external_link_url", with: "https://www.mycoportal.org/portal/collections/456")
      click_commit
    end
    assert_no_selector("#modal_external_link_#{link.id}")
    assert_equal(link.reload.url, "https://www.mycoportal.org/portal/collections/456")

    # try remove links
    # external_link
    within("#observation_external_links") do
      assert_button(text: :destroy_object.t(type: :external_link))
      accept_confirm do
        find(:css, ".destroy_external_link_link_#{link.id}").trigger("click")
      end
      assert_no_link(text: /MycoPortal/)
    end
  end
end
