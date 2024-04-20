# frozen_string_literal: true

require("application_system_test_case")

class ObservationShowSystemTest < ApplicationSystemTestCase
  def test_add_and_edit_associated_records
    obs = observations(:peltigera_obs)

    # browser = page.driver.browser
    rolf = users("rolf")
    login!(rolf)

    assert_link("Your Observations")
    click_on("Your Observations")
    # obs = observations(:peltigera_obs)

    assert_selector("body.observations__index")
    assert_link(text: /#{obs.text_name}/)
    click_link(text: /#{obs.text_name}/)
    assert_selector("body.observations__show")

    scroll_to(find("#observation_collection_numbers"), align: :center)
    assert_link(:create_collection_number.l)
    assert_selector(".new_collection_number_link")
    # click_link(:create_collection_number.l) # it's too small to click
    first(:css, ".new_collection_number_link").trigger("click")

    assert_selector("#modal_collection_number", wait: 6)

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

    assert_selector("#modal_collection_number_#{c_n.id}", wait: 6)

    within("#modal_collection_number_#{c_n.id}") do
      assert_field("collection_number_number")
      fill_in("collection_number_number", with: "021345")
      click_commit
    end
    assert_no_selector("#modal_collection_number_#{c_n.id}")

    within("#observation_collection_numbers") do
      assert_link(text: /021345/)
    end

    assert_equal(c_n.reload.number, "021345")

    # Has a fungarium record: :field_museum_record. Try edit
    fmr = herbarium_records(:field_museum_record)
    within("#observation_herbarium_records") do
      assert_link(text: /#{fmr.accession_number}/)
      assert_link(:edit_herbarium_record.l)
      find(:css, ".edit_herbarium_record_link_#{fmr.id}").trigger("click")
    end

    assert_selector("#modal_herbarium_record_#{fmr.id}", wait: 6)

    within("#modal_herbarium_record_#{fmr.id}") do
      assert_field("herbarium_record_accession_number")
      fill_in("herbarium_record_accession_number", with: "6234234")
      click_commit
    end
    assert_no_selector("#modal_herbarium_record_#{fmr.id}")

    within("#observation_herbarium_records") do
      assert_link(text: /6234234/)
    end

    # new sequence
    assert_link(:show_observation_add_sequence.l)
    find(:css, ".new_sequence_link").trigger("click")

    assert_selector("#modal_sequence", wait: 6)
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

    within("#modal_sequence_#{seq.id}") do
      fill_in("sequence_notes", with: "Oh yea.")
      click_commit
    end
    assert_equal(seq.reload.notes, "Oh yea.")
    assert_no_selector("#modal_sequence_#{seq.id}")

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

    within("#modal_external_link_#{link.id}") do
      assert_field("external_link_url")
      fill_in("external_link_url",
              with: "https://wedont.validatethese.urls/yet")
      click_commit
    end
    assert_no_selector("#modal_external_link_#{link.id}")
    assert_equal(link.reload.url, "https://wedont.validatethese.urls/yet")

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
    assert_no_link(text: /021345/)

    # herbarium_record
    within("#observation_herbarium_records") do
      assert_link(:REMOVE.l)
      find(:css, ".remove_herbarium_record_link_#{fmr.id}").trigger("click")
    end
    # confirm is in modal
    assert_selector("#modal_herbarium_record_observation")
    within("#modal_herbarium_record_observation") do
      assert_button(:REMOVE.l)
      find(:css, ".remove_herbarium_record_link_#{fmr.id}").trigger("click")
    end
    assert_no_selector("#modal_herbarium_record_observation")
    assert_no_link(text: /6234234/)

    # sequence
    within("#observation_sequences") do
      assert_button(:destroy_object.t(type: :sequence))
      accept_confirm do
        find(:css, ".destroy_sequence_link_#{seq.id}").trigger("click")
      end
      assert_no_link(text: /LSU/)
    end

    # external_link
    within("#observation_external_links") do
      assert_button(text: :destroy_object.t(type: :external_link))
      accept_confirm do
        find(:css, ".destroy_external_link_link_#{link.id}").trigger("click")
      end
      assert_no_link(text: /MycoPortal/)
    end
  end

  def test_add_and_edit_naming_and_comment
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
    assert_selector("#namings")

    # new naming
    n_d = names(:namings_deprecated) # Xa current
    nd1 = names(:namings_deprecated_1)

    scroll_to(find("#namings"), align: :center)
    within("#namings") do
      assert_link(text: /Propose/)
      click_link(text: /Propose/)
    end

    assert_selector("#modal_obs_#{obs.id}_naming", wait: 9)
    assert_selector("#obs_#{obs.id}_naming_form", wait: 9)
    within("#obs_#{obs.id}_naming_form") do
      assert_field("naming_name", wait: 4)
      # fill_in("naming_name", with: nd1.text_name)
      # Using autocomplete to slow things down here, otherwise button blocked.
      find_field("naming_name").click
      nam = nd1.text_name[0..-2]
      browser.keyboard.type(nam)
      assert_selector(".auto_complete", wait: 4)
      browser.keyboard.type(:down, :tab)
      assert_no_selector(".auto_complete")
      click_commit
    end

    assert_selector(
      "#modal_obs_#{obs.id}_naming_flash",
      text: :form_observations_there_is_a_problem_with_name.t.html_to_ascii
    )
    assert_selector("#name_messages", text: /deprecated/)

    within("#obs_#{obs.id}_naming_form") do
      fill_in("naming_name", with: "")
      # fill_in("naming_name", with: n_d.text_name)
      # Using autocomplete to slow things down here, otherwise session lost.
      find_field("naming_name").click
      nam = n_d.text_name[0..-2]
      browser.keyboard.type(nam)
      assert_selector(".auto_complete", wait: 4)
      browser.keyboard.type(:down, :tab)
      assert_no_selector(".auto_complete")
      assert_selector("#naming_vote_value")
      select("Doubtful", from: "naming_vote_value")
      click_commit
    end
    assert_no_selector("#modal_obs_#{obs.id}_naming", wait: 6)

    # Test problems have occurred here: Something in
    # Observations::NamingsController#create seems to execute before the
    # previous action can rewrite the cookie, so we lose the session_user.
    # When this happens, naming_table is refreshed with no edit/destroy buttons.
    # Capybara author suggests trying sleep(5) after a CRUD action
    # Ah. Maybe it was just missing the scroll_to
    scroll_to(find("#namings"), align: :center)
    sleep(2)

    nam = Naming.last
    assert_equal(n_d.text_name, nam.text_name)
    within("#namings") do
      assert_link(text: /#{n_d.text_name}/)
      assert_selector(".destroy_naming_link_#{nam.id}")
      assert_selector("#naming_vote_form_#{nam.id}")
      select("Could Be", from: "vote_value_#{nam.id}")
    end

    assert_no_selector("#mo_ajax_progress")
    assert_selector("#title", text: /#{obs.text_name}/)
    # sleep(3)

    within("#namings") do
      assert_link(text: /#{n_d.text_name}/)
      assert_selector("#naming_vote_form_#{nam.id}")
      select("I'd Call It That", from: "vote_value_#{nam.id}")
    end
    # assert_selector("#mo_ajax_progress", wait: 4)
    # assert_selector("#mo_ajax_progress_caption",
    #                 text: /#{:show_namings_saving.l}/)

    assert_no_selector("#mo_ajax_progress")
    assert_selector("#title", text: /#{nam.text_name}/)
    # sleep(3)

    # check that there is a vote "index" tally with this naming
    within("#namings") do
      assert_link(href: "/observations/#{obs.id}/namings/#{nam.id}/votes")
      click_link(href: "/observations/#{obs.id}/namings/#{nam.id}/votes")
    end
    assert_selector("#modal_naming_votes_#{nam.id}")

    within("#modal_naming_votes_#{nam.id}") do
      assert_text(nam.text_name)
      find(:css, ".close").click
    end
    assert_no_selector("#modal_naming_votes_#{nam.id}")

    # Test the link to the naming name and user
    within("#namings") do
      assert_link(text: /#{n_d.text_name}/)
      click_link(text: /#{n_d.text_name}/)
    end
    assert_selector("body.names__show", wait: 15)
    page.go_back

    # Test the link to the naming user... whoa, this takes too long!
    # Re-add this test when the user page is sped up.
    # within("#namings") do
    #   assert_link(text: /#{rolf.login}/)
    #   click(text: /#{rolf.login}/)
    # end
    # assert_selector("body.users__show", wait: 30)
    # page.go_back

    # Test the edit naming form link.
    within("#namings") do
      assert_link(text: /#{n_d.text_name}/)
      assert_selector(".edit_naming_link_#{nam.id}")
      find(:css, ".edit_naming_link_#{nam.id}").trigger("click")
    end
    assert_selector("#modal_obs_#{obs.id}_naming_#{nam.id}", wait: 9)
    assert_selector("#obs_#{obs.id}_naming_#{nam.id}_form", wait: 9)
    within("#modal_obs_#{obs.id}_naming_#{nam.id}") do
      find(:css, ".close").click
    end
    assert_no_selector("#modal_obs_#{obs.id}_naming_#{nam.id}")

    within("#namings") do
      assert_link(text: /#{n_d.text_name}/)
      assert_selector(".destroy_naming_link_#{nam.id}")
      accept_prompt do
        find(:css, ".destroy_naming_link_#{nam.id}").trigger("click")
      end
      assert_no_link(text: /#{n_d.text_name}/, wait: 9)
    end
    assert_selector("#title", text: /#{obs.text_name}/)

    assert_selector("#comments_for_object")
    within("#comments_for_object") do
      assert_link(:show_comments_add_comment.l)
      find(:css, ".new_comment_link_#{obs.id}").trigger("click")
    end

    assert_selector("#modal_comment")
    within("#modal_comment") do
      assert_selector("#comment_comment")
      fill_in("comment_comment", with: "What do you mean, Coprinus?")
      click_commit
    end
    # Cannot submit comment without summary
    assert_selector("#modal_comment_flash", text: /Missing/)
    within("#modal_comment") do
      assert_selector("#comment_comment", text: "What do you mean, Coprinus?")
      fill_in("comment_summary", with: "A load of bollocks")
      click_commit
    end
    assert_no_selector("#modal_comment")

    com = Comment.last
    within("#comments_for_object") do
      assert_text("A load of bollocks")
      assert_selector(".show_user_link_#{rolf.id}")
      assert_selector(".edit_comment_link_#{com.id}")
      assert_selector(".destroy_comment_link_#{com.id}")
      find(:css, ".edit_comment_link_#{com.id}").trigger("click")
    end

    assert_selector("#modal_comment_#{com.id}")
    within("#modal_comment_#{com.id}") do
      fill_in("comment_summary", with: "Exciting discovery")
      fill_in("comment_comment", with: "What I meant was, Coprinus!")
      click_commit
    end
    assert_no_selector("#modal_comment_#{com.id}")

    within("#comments_for_object") do
      assert_no_text("A load of bollocks")
      assert_text("Exciting discovery")
      assert_selector(".destroy_comment_link_#{com.id}")
      accept_confirm do
        find(:css, ".destroy_comment_link_#{com.id}").trigger("click")
      end

      assert_no_text("Exciting discovery")
      assert_no_selector(".destroy_comment_link_#{com.id}")
    end
  end
end
