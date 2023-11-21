# frozen_string_literal: true

require("test_helper")

class NamingsIntegrationTest < CapybaraIntegrationTestCase
  # --------------------------------------
  #  Test proposing and voting on names.
  # --------------------------------------

  def test_proposing_names
    namer_session = open_session
    voter_session = open_session
    namer = katrina
    voter = rolf

    obs = observations(:detailed_unknown_obs)
    # (Make sure Katrina doesn't own any comments on this observation yet.)
    assert_false(obs.comments.any? { |c| c.user == namer })
    # (Make sure the name we are going to suggest doesn't exist yet.)
    text_name = "Xylaria polymorpha"
    assert_nil(Name.find_by(text_name: text_name))
    original_name = obs.name

    namer_session.visit("/#{obs.id}")
    namer_session.assert_selector("body.observations__show")
    login(namer, session: namer_session)
    assert_false(namer_session.has_link?(class: /edit_naming/))
    assert_false(namer_session.has_selector?(class: /destroy_naming_link_/))
    namer_session.click_link(class: "propose-naming-link")

    # naming = namer_session.create_name(obs, text_name)
    namer_session.assert_selector("body.namings__new")
    # (Make sure the form is for the correct object!)
    namer_session.assert_selector(
      "form[action*='/observations/#{obs.id}/namings']"
    )
    # (Make sure there is a tab to go back to observations/show.)
    assert_true(namer_session.has_link?(href: "/#{obs.id}"))

    namer_session.within("#naming_form") do |form|
      assert_true(form.has_field?("naming_name", text: ""))
      assert_true(form.has_field?("naming_vote_value", text: ""))
      assert_true(form.has_unchecked_field?("naming_reasons_1_check"))
      assert_true(form.has_unchecked_field?("naming_reasons_2_check"))
      assert_true(form.has_unchecked_field?("naming_reasons_3_check"))
      assert_true(form.has_unchecked_field?("naming_reasons_4_check"))
      form.first("input[type='submit']").click
    end
    namer_session.assert_selector("body.namings__create")
    # (I don't care so long as it says something.)
    assert_flash_text(/\S/, session: namer_session)

    namer_session.within("#naming_form") do |form|
      form.fill_in("naming_name", with: text_name)
      form.first("input[type='submit']").click
    end
    namer_session.assert_selector("body.namings__create")
    assert_true(namer_session.has_selector?(
                  ".alert-warning",
                  text: /MO does not recognize the name.*#{text_name}/
                ))

    namer_session.within("#naming_form") do |form|
      assert_true(form.has_field?("naming_name", with: text_name))
      assert_true(form.has_unchecked_field?("naming_reasons_1_check"))
      assert_true(form.has_unchecked_field?("naming_reasons_2_check"))
      assert_true(form.has_unchecked_field?("naming_reasons_3_check"))
      assert_true(form.has_unchecked_field?("naming_reasons_4_check"))
      form.select("I'd Call It That", from: "naming_vote_value")
      form.first("input[type='submit']").click
    end
    namer_session.assert_selector("body.observations__show")
    assert_flash_success(session: namer_session)
    assert_true(namer_session.has_text?("Observation #{obs.id}"))

    obs.reload
    name = Name.find_by(text_name: text_name)
    naming = Naming.last
    assert_names_equal(name, naming.name)
    assert_names_equal(name, obs.name)
    assert_equal("", name.author.to_s)

    # (Make sure naming shows up somewhere.)
    assert_true(namer_session.has_text?(text_name))
    # (Make sure there is an edit and destroy control for the new naming.)
    # (Now one: same for wide-screen as for mobile.)
    assert_true(namer_session.has_link?(
                  class: /edit_naming_link_#{naming.id}/
                ))
    namer_session.assert_selector(".destroy_naming_link_#{naming.id}")

    # Try changing it.
    author = "(Pers.) Grev."
    reason = "Test reason."
    namer_session.click_link(class: /edit_naming_link_#{naming.id}/)
    namer_session.assert_selector("body.namings__edit")
    namer_session.within("#naming_form") do |form|
      assert_true(form.has_field?("naming_name", with: text_name))
      assert_true(form.has_checked_field?("naming_reasons_1_check"))
      form.uncheck("naming_reasons_1_check")
      form.fill_in("naming_name", with: "#{text_name} #{author}")
      form.check("naming_reasons_2_check")
      form.fill_in("naming_reasons_2_notes", with: reason)
      form.select("I'd Call It That", from: "naming_vote_value")
      form.first("input[type='submit']").click
    end
    namer_session.assert_selector("body.observations__show")
    assert_true(namer_session.has_text?("Observation #{obs.id}"))

    obs.reload
    name.reload
    naming.reload
    assert_equal(author, name.author)
    assert_names_equal(name, naming.name)
    assert_names_equal(name, obs.name)

    # (Make sure author shows up somewhere.)
    assert_true(namer_session.has_text?(author))
    # (Make sure reason shows up, too.)
    assert_true(namer_session.has_text?(reason))

    namer_session.click_link(class: /edit_naming_link_#{naming.id}/)
    namer_session.assert_selector("body.namings__edit")
    namer_session.within("#naming_form") do |form|
      assert_true(
        form.has_field?("naming_name", with: "#{text_name} #{author}")
      )
      assert_true(form.has_unchecked_field?("naming_reasons_1_check"))
      assert_true(form.has_field?("naming_reasons_1_notes", text: ""))
      assert_true(form.has_checked_field?("naming_reasons_2_check"))
      assert_true(form.has_field?("naming_reasons_2_notes", with: reason))
      assert_true(form.has_unchecked_field?("naming_reasons_3_check"))
      assert_true(form.has_field?("naming_reasons_3_notes", text: ""))
    end
    namer_session.click_link(text: "Cancel (Show Observation)")

    login(voter, session: voter_session)
    assert_not_equal(namer_session.driver.request.cookies["mo_user"],
                     voter_session.driver.request.cookies["mo_user"])
    # Note that this only tests non-JS vote submission.
    # Most users will have their vote sent via AJAX from naming_vote_ajax.js
    # voter_session.vote_on_name(obs, naming)
    voter_session.visit("/#{obs.id}")
    voter_session.within("#naming_vote_form_#{naming.id}") do |form|
      assert_true(form.has_select?("vote_value", selected: nil))
      form.select("I'd Call It That", from: "vote_value")
      assert_true(form.has_select?("vote_value",
                                   selected: "I'd Call It That"))
      form.first("input[type='submit']").click
    end
    # assert_template("observations/show")
    assert_true(voter_session.has_text?("I'd Call It That"))

    # namer tries to delete
    # namer_session.failed_delete(obs)
    namer_session.click_button(class: "destroy_naming_link_#{naming.id}")
    assert_flash_text("Sorry", session: namer_session)

    # voter_session.change_mind(obs, naming)
    voter_session.visit("/#{obs.id}")
    voter_session.within("#naming_vote_form_#{naming.id}") do |form|
      form.select("As If!", from: "vote_value")
      assert_true(form.has_select?("vote_value", selected: "As If!"))
      form.first("input[type='submit']").click
    end

    # namer_session.successful_delete(obs, naming, text_name, orignal_name)
    namer_session.click_button(class: "destroy_naming_link_#{naming.id}")
    namer_session.assert_selector("body.observations__show")
    assert_true(namer_session.has_text?("Observation #{obs.id}"))
    assert_flash_success(session: namer_session)

    obs.reload
    assert_names_equal(original_name, obs.name)
    assert_nil(Naming.safe_find(naming.id))
    assert_false(namer_session.has_text?(text_name))
  end
end
