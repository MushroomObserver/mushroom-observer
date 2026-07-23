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

    scroll_to(find_by_id("observation_collection_numbers"), align: :center)
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

    # try remove button (uses turbo_confirm modal)
    within("#observation_collection_numbers") do
      assert_button(:remove.ti)
      find(:css, ".remove_collection_number_link_#{c_n.id}").click
    end
    # confirm modal appears
    assert_selector("#mo_confirm", visible: true)
    within("#mo_confirm") do
      click_button(class: "btn-danger")
    end
    assert_no_selector("#mo_confirm", visible: true)
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
      # Uses namespaced target: data-autocompleter--herbarium-target
      assert_selector(
        "span.has-id-indicator" \
        "[data-autocompleter--herbarium-target='hasIdIndicator']",
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

    # Test remove herbarium record (uses turbo_confirm modal)
    within("#observation_herbarium_records") do
      # Verify remove button has text-danger class
      assert_selector("button.text-danger", text: :remove.ti)
      click_button(:remove.ti)
    end
    # confirm modal appears
    assert_selector("#mo_confirm", visible: true)
    within("#mo_confirm") do
      click_button(class: "btn-danger")
    end
    assert_no_selector("#mo_confirm", visible: true)

    # Record should be removed from the list
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
      assert_link(:edit.ti)
      find(:css, ".edit_sequence_link_#{seq.id}").trigger("click")
    end

    within("#modal_sequence_#{seq.id}") do
      fill_in("sequence_notes", with: "Oh yea.")
      click_commit
    end
    assert_equal("Oh yea.", seq.reload.notes)
    assert_no_selector("#modal_sequence_#{seq.id}")

    # try remove button (uses turbo_confirm modal)
    within("#observation_sequences") do
      assert_button(:destroy_object.t(type: :sequence))
      find(:css, ".destroy_sequence_link_#{seq.id}").click
    end
    # confirm modal appears
    assert_selector("#mo_confirm", visible: true)
    within("#mo_confirm") do
      click_button(class: "btn-danger")
    end
    assert_no_selector("#mo_confirm", visible: true)
    assert_no_link(text: /LSU/)
  end

  def test_add_and_edit_external_links
    login!(users("mary"))
    visit(observation_path(@obs))
    assert_selector("body.observations__show")

    site = external_sites(:mycoportal)
    within("#observation_external_links") do
      assert_link(text: :add.ti)
      find_link(:add.ti).trigger("click")
    end

    # external_id is active by default; the url field is grayed (readonly)
    assert_selector("#modal_external_link")
    within("#modal_external_link") do
      assert_field("external_link_external_id", readonly: false)
      assert_field("external_link_url", readonly: true)
      select(site.name, from: "external_link_external_site_id")
      fill_in("external_link_external_id", with: "12212326")
      click_commit
    end
    sleep(1)
    assert_no_selector("#modal_external_link")

    link = ExternalLink.last
    assert_equal("12212326", link.external_id)
    assert_nil(link.url, "an external_id link stores no url")

    within("#observation_external_links") do
      assert_link(text: /MyCoPortal/)
      find_link(:edit.ti).trigger("click")
    end

    # edit: change the external_id
    within("#modal_external_link_#{link.id}") do
      fill_in("external_link_external_id", with: "13629347")
      click_commit
    end
    assert_no_selector("#modal_external_link_#{link.id}")
    assert_equal("13629347", link.reload.external_id)

    # remove (turbo_confirm modal)
    within("#observation_external_links") do
      assert_button(text: :destroy_object.t(type: :external_link))
      find(:css, ".destroy_external_link_link_#{link.id}").click
    end
    assert_selector("#mo_confirm", visible: true)
    within("#mo_confirm") do
      click_button(class: "btn-danger")
    end
    assert_no_selector("#mo_confirm", visible: true)
    within("#observation_external_links") do
      assert_no_link(text: /MyCoPortal/)
    end
  end
end
