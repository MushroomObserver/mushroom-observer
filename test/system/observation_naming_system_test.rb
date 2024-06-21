# frozen_string_literal: true

require("application_system_test_case")

class ObservationNamingSystemTest < ApplicationSystemTestCase
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
    n_d = names(:namings_deprecated) # Xa current
    nd1 = names(:namings_deprecated_1)

    scroll_to(find("#observation_namings"), align: :center)
    within("#observation_namings") do
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
    scroll_to(find("#observation_namings"), align: :center)
    sleep(2)

    nam = Naming.last
    assert_equal(n_d.text_name, nam.text_name)
    within("#observation_namings") do
      assert_link(text: /#{n_d.text_name}/)
      assert_selector(".destroy_naming_link_#{nam.id}")
      assert_selector("#naming_vote_form_#{nam.id}")
      select("Could Be", from: "vote_value_#{nam.id}")
    end

    assert_no_selector("#mo_ajax_progress")
    assert_selector("#title", text: /#{obs.text_name}/)
    # sleep(3)

    within("#observation_namings") do
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
    within("#observation_namings") do
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
    within("#observation_namings") do
      assert_link(text: /#{n_d.text_name}/)
      click_link(text: /#{n_d.text_name}/)
    end
    assert_selector("body.names__show", wait: 15)
    page.go_back

    # Test the link to the naming user... whoa, this takes too long!
    # Re-add this test when the user page is sped up.
    # within("#observation_namings") do
    #   assert_link(text: /#{rolf.login}/)
    #   click(text: /#{rolf.login}/)
    # end
    # assert_selector("body.users__show", wait: 30)
    # page.go_back

    # Test the edit naming form link.
    within("#observation_namings") do
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

    within("#observation_namings") do
      assert_link(text: /#{n_d.text_name}/)
      assert_selector(".destroy_naming_link_#{nam.id}")
      accept_prompt do
        find(:css, ".destroy_naming_link_#{nam.id}").trigger("click")
      end
      assert_no_link(text: /#{n_d.text_name}/, wait: 9)
    end
    assert_selector("#title", text: /#{obs.text_name}/)
  end
end
